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

subprojects {
    if (project.name != "app") {
        project.evaluationDependsOn(":app")
    }
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
    val configureCompileSdk = {
        if (plugins.hasPlugin("com.android.library")) {
            extensions.configure<LibraryExtension> {
                // isar_flutter_libs fixa 30; sqflite_android exige API 36 (BAKLAVA).
                compileSdk = 36
            }
        }
    }
    if (state.executed) {
        configureCompileSdk()
    } else {
        afterEvaluate {
            configureCompileSdk()
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
