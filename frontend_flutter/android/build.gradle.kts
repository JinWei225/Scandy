allprojects {
    repositories {
        google()
        mavenCentral()
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

// `receive_sharing_intent` declares compileSdk 37, which is not installed under
// that name — the SDK manager lays it down as the preview "android-37.0", so
// the build fails with "Failed to find target with hash string 'android-37'".
// Pinning plugin subprojects to the newest stable platform we do have keeps
// them consistent with :app instead of each chasing its own SDK.
// Revisit once platform 37 ships stable and Flutter's default catches up.
//
// This must be registered BEFORE the `evaluationDependsOn(":app")` block below:
// that block forces evaluation as it iterates, and afterEvaluate throws on a
// project that has already been evaluated.
//
// The extension is reached by reflection because the Android Gradle Plugin is
// applied to the subprojects, not to this root script, so its types are not on
// this script's compile classpath.
val pinnedCompileSdk = 36

subprojects {
    afterEvaluate {
        val androidExt = extensions.findByName("android") ?: return@afterEvaluate
        runCatching {
            val current = androidExt.javaClass
                .getMethod("getCompileSdkVersion")
                .invoke(androidExt) as? String
            // "android-37.0" -> 37, "android-36" -> 36
            val currentMajor = current
                ?.removePrefix("android-")
                ?.substringBefore('.')
                ?.toIntOrNull()
            if (currentMajor != null && currentMajor > pinnedCompileSdk) {
                androidExt.javaClass
                    .getMethod("compileSdkVersion", Int::class.javaPrimitiveType)
                    .invoke(androidExt, pinnedCompileSdk)
                logger.lifecycle(
                    "Pinned ${project.name} compileSdk $current -> $pinnedCompileSdk"
                )
            }
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
