import fs from 'node:fs';
import jwt from 'jsonwebtoken';

const BASE = 'https://api.appstoreconnect.apple.com';

/** Minimal App Store Connect API client (JWT auth, JSON:API envelope). */
export class AscClient {
  constructor({ issuerId, keyId, privateKeyPath }) {
    this.issuerId = issuerId;
    this.keyId = keyId;
    this.privateKey = fs.readFileSync(privateKeyPath, 'utf8');
  }

  _token() {
    // ASC tokens are valid max 20 minutes; mint a fresh one per request batch.
    return jwt.sign(
      { iss: this.issuerId, aud: 'appstoreconnect-v1' },
      this.privateKey,
      { algorithm: 'ES256', expiresIn: '15m', keyid: this.keyId },
    );
  }

  async request(method, path, body) {
    // Retry transient network errors and 5xx responses.
    for (let attempt = 1; ; attempt++) {
      let res;
      try {
        res = await fetch(`${BASE}${path}`, {
          method,
          headers: {
            Authorization: `Bearer ${this._token()}`,
            'Content-Type': 'application/json',
          },
          body: body ? JSON.stringify(body) : undefined,
        });
      } catch (err) {
        if (attempt >= 3) throw err;
        await new Promise((r) => setTimeout(r, attempt * 5_000));
        continue;
      }
      if (res.status >= 500 && attempt < 3) {
        await new Promise((r) => setTimeout(r, attempt * 5_000));
        continue;
      }
      if (res.status === 204) return null;
      const json = await res.json().catch(() => null);
      if (!res.ok) {
        const detail = json?.errors?.map((e) => `${e.title}: ${e.detail}`).join('; ');
        throw new Error(`ASC ${method} ${path} -> ${res.status} ${detail ?? ''}`);
      }
      return json;
    }
  }

  /** All in-app events for the app, paginated. */
  async listEvents(appId) {
    const events = [];
    let path = `/v1/apps/${appId}/appEvents?limit=50`;
    while (path) {
      const page = await this.request('GET', path);
      events.push(...(page.data ?? []));
      path = page.links?.next ? page.links.next.replace(BASE, '') : null;
    }
    return events;
  }

  /** All App Store territory IDs (e.g. USA, DEU, ...). */
  async listTerritoryIds() {
    const ids = [];
    let path = '/v1/territories?limit=200';
    while (path) {
      const page = await this.request('GET', path);
      ids.push(...(page.data ?? []).map((t) => t.id));
      path = page.links?.next ? page.links.next.replace(BASE, '') : null;
    }
    return ids;
  }

  async createEvent(appId, attrs) {
    const res = await this.request('POST', '/v1/appEvents', {
      data: {
        type: 'appEvents',
        attributes: attrs,
        relationships: { app: { data: { type: 'apps', id: appId } } },
      },
    });
    return res.data;
  }

  async updateEvent(eventId, attrs) {
    const res = await this.request('PATCH', `/v1/appEvents/${eventId}`, {
      data: { type: 'appEvents', id: eventId, attributes: attrs },
    });
    return res.data;
  }

  async createLocalization(eventId, { locale, name, shortDescription, longDescription }) {
    const res = await this.request('POST', '/v1/appEventLocalizations', {
      data: {
        type: 'appEventLocalizations',
        attributes: { locale, name, shortDescription, longDescription },
        relationships: {
          appEvent: { data: { type: 'appEvents', id: eventId } },
        },
      },
    });
    return res.data;
  }

  /**
   * Upload one event image for a localization.
   * assetType: 'EVENT_CARD' (1920x1080) or 'EVENT_DETAILS_PAGE' (1080x1920).
   * Three-step ASC asset flow: reserve -> PUT chunks -> commit.
   */
  async uploadScreenshot(localizationId, assetType, fileName, buffer) {
    // The reserve -> PUT -> commit flow can end up in a bad state after a
    // flaky chunk upload; verify and redo the whole upload if needed.
    for (let attempt = 1; ; attempt++) {
      try {
        return await this._uploadScreenshotOnce(localizationId, assetType, fileName, buffer);
      } catch (err) {
        if (attempt >= 3) throw err;
        await new Promise((r) => setTimeout(r, 5_000));
      }
    }
  }

  /** Localizations already attached to an event. */
  async listLocalizations(eventId) {
    const res = await this.request(
      'GET',
      `/v1/appEvents/${eventId}/localizations?limit=50`,
    );
    return res?.data ?? [];
  }

  /** Screenshots already attached to a localization. */
  async listScreenshots(localizationId) {
    const res = await this.request(
      'GET',
      `/v1/appEventLocalizations/${localizationId}/appEventScreenshots?limit=50`,
    );
    return res?.data ?? [];
  }

  _reserveScreenshot(localizationId, assetType, fileName, buffer) {
    return this.request('POST', '/v1/appEventScreenshots', {
      data: {
        type: 'appEventScreenshots',
        attributes: { fileName, fileSize: buffer.length, appEventAssetType: assetType },
        relationships: {
          appEventLocalization: {
            data: { type: 'appEventLocalizations', id: localizationId },
          },
        },
      },
    });
  }

  async _uploadScreenshotOnce(localizationId, assetType, fileName, buffer) {
    let reservation;
    try {
      reservation = await this._reserveScreenshot(localizationId, assetType, fileName, buffer);
    } catch (err) {
      if (!/already exists/i.test(err.message)) throw err;
      // A retried POST (or earlier crashed run) left an asset on this slot.
      // Keep it if it's fully uploaded, otherwise clear it and re-reserve.
      for (const s of await this.listScreenshots(localizationId)) {
        if (s.attributes.appEventAssetType !== assetType) continue;
        const state = s.attributes.assetDeliveryState?.state;
        if (state === 'COMPLETE' || state === 'UPLOAD_COMPLETE') return s.id;
        await this.request('DELETE', `/v1/appEventScreenshots/${s.id}`).catch(() => {});
      }
      reservation = await this._reserveScreenshot(localizationId, assetType, fileName, buffer);
    }

    for (const op of reservation.data.attributes.uploadOperations ?? []) {
      const chunk = buffer.subarray(op.offset, op.offset + op.length);
      const headers = Object.fromEntries(
        (op.requestHeaders ?? []).map((h) => [h.name, h.value]),
      );
      for (let attempt = 1; ; attempt++) {
        try {
          const up = await fetch(op.url, { method: op.method, headers, body: chunk });
          if (!up.ok) throw new Error(`Asset chunk upload failed: ${up.status}`);
          break;
        } catch (err) {
          if (attempt >= 3) throw err;
          await new Promise((r) => setTimeout(r, attempt * 5_000));
        }
      }
    }

    try {
      await this.request('PATCH', `/v1/appEventScreenshots/${reservation.data.id}`, {
        data: {
          type: 'appEventScreenshots',
          id: reservation.data.id,
          attributes: { uploaded: true },
        },
      });
    } catch (err) {
      if (!/already uploaded|upload has failed/i.test(err.message)) throw err;
      // Ambiguous 409 - check the real delivery state before deciding.
      const check = await this.request('GET', `/v1/appEventScreenshots/${reservation.data.id}`);
      const state = check?.data?.attributes?.assetDeliveryState?.state;
      if (state === 'FAILED') {
        await this.request('DELETE', `/v1/appEventScreenshots/${reservation.data.id}`).catch(() => {});
        throw new Error(`Asset delivery failed for ${fileName}, retrying upload`);
      }
      // Already committed (COMPLETE / UPLOAD_COMPLETE / AWAITING_UPLOAD race) - fine.
    }
    return reservation.data.id;
  }

  /**
   * Submit an event for App Review via the reviewSubmissions flow
   * (create submission -> attach the event as an item -> submit).
   */
  async submitEvent(appId, eventId) {
    // Reuse an open (never-submitted) submission if one exists - Apple caps
    // open submissions per app, and a failed attach would otherwise leak one.
    const open = await this.request(
      'GET',
      `/v1/reviewSubmissions?filter[app]=${appId}&filter[state]=READY_FOR_REVIEW&limit=1`,
    );
    const submission =
      open?.data?.length > 0
        ? { data: open.data[0] }
        : await this.request('POST', '/v1/reviewSubmissions', {
            data: {
              type: 'reviewSubmissions',
              attributes: { platform: 'IOS' },
              relationships: { app: { data: { type: 'apps', id: appId } } },
            },
          });
    try {
      await this.request('POST', '/v1/reviewSubmissionItems', {
        data: {
          type: 'reviewSubmissionItems',
          relationships: {
            reviewSubmission: {
              data: { type: 'reviewSubmissions', id: submission.data.id },
            },
            appEvent: { data: { type: 'appEvents', id: eventId } },
          },
        },
      });
    } catch (err) {
      // Retried attach after a failed submit step - the item is already there.
      if (!/already added/i.test(err.message)) throw err;
    }
    await this.request('PATCH', `/v1/reviewSubmissions/${submission.data.id}`, {
      data: {
        type: 'reviewSubmissions',
        id: submission.data.id,
        attributes: { submitted: true },
      },
    });
    return submission.data.id;
  }
}
