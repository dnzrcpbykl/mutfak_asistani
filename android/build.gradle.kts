buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        // Android Gradle Plugin versiyonu projenle uyumlu olmalı,
        // genellikle varsayılan ayarlarda bu blok gizli olabilir ama
        // Firebase için şu satırı eklememiz şart:
        classpath("com.google.gms:google-services:4.4.2")
        classpath("com.android.tools.build:gradle:8.2.1")
    }
}

allprojects {
    repositories {
        google()
        mavenCentral()
    }

    tasks.withType<JavaCompile> {
        sourceCompatibility = "17"
        targetCompatibility = "17"
        // Eğer üstteki satırlar hata verirse alternatif olarak şunu kullanabilirsin:
        // options.release.set(17) 
        options.compilerArgs.add("-Xlint:-options")
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
