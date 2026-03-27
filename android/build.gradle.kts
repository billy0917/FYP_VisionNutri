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

    // Fix old Flutter plugins that don't declare a namespace (required by AGP 8+)
    project.plugins.withType<com.android.build.gradle.LibraryPlugin> {
        val ext = project.extensions.getByType<com.android.build.gradle.LibraryExtension>()
        if (ext.namespace.isNullOrBlank()) {
            ext.namespace = "com.example.${project.name.replace("-", "_").replace(".", "_")}"
        }
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
