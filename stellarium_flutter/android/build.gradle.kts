allprojects {
    repositories {
        google()
        mavenCentral()
    }
    // posthog_flutter 5.30.0 asks for posthog-android "[3.51.0,4.0.0]", which
    // now resolves to 4.0.0 - a major release the plugin does not compile
    // against. Hold the last 3.x until posthog_flutter is upgraded.
    configurations.all {
        resolutionStrategy.force("com.posthog:posthog-android:3.73.1")
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
