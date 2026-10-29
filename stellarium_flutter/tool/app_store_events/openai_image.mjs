import sharp from 'sharp';

const OPENAI_URL = 'https://api.openai.com/v1/images/generations';

/** Generate an image via the OpenAI Images API, returns a PNG buffer. */
async function generate(prompt, size) {
  // Read env at call time so .env loaded by the entrypoint is picked up.
  const model = process.env.IMAGE_MODEL ?? 'gpt-image-2';
  const res = await fetch(OPENAI_URL, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${process.env.OPENAI_API_KEY}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({ model, prompt, size, quality: 'high', n: 1 }),
  });
  const json = await res.json();
  if (!res.ok) {
    throw new Error(`OpenAI images (${model}) -> ${res.status}: ${json.error?.message ?? 'unknown'}`);
  }
  return Buffer.from(json.data[0].b64_json, 'base64');
}

/**
 * Generate event art at Apple's exact required dimensions.
 * The API generates at its native sizes; we cover-resize to the target so
 * composition is preserved and edges crop symmetrically.
 */
export async function generateEventArt(prompt, { width, height }) {
  // Pick the native generation size with the matching orientation.
  const nativeSize = width >= height ? '1536x1024' : '1024x1536';
  const raw = await generate(prompt, nativeSize);
  return sharp(raw)
    .resize(width, height, { fit: 'cover', position: 'centre' })
    .png()
    .toBuffer();
}

export const ASSET_SPECS = {
  EVENT_CARD: { width: 1920, height: 1080 },
  EVENT_DETAILS_PAGE: { width: 1080, height: 1920 },
};
