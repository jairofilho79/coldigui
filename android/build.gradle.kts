import com.android.build.gradle.LibraryExtension

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

// Plugins antigos (ex.: isar_flutter_libs) sem namespace/compileSdk — AGP 8+ exige.
subprojects {
    pluginManager.withPlugin("com.android.library") {
        extensions.configure<LibraryExtension> {
            if (namespace.isNullOrBlank()) {
                namespace = project.group.toString()
            }
        }
    }
    afterEvaluate {
        if (plugins.hasPlugin("com.android.library")) {
            extensions.configure<LibraryExtension> {
                // isar_flutter_libs fixa compileSdkVersion 30; lStar exige API 31+.
                compileSdk = 35
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
