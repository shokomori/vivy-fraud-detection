import org.jetbrains.kotlin.gradle.dsl.JvmTarget
import org.jetbrains.kotlin.gradle.tasks.KotlinJvmCompile
import org.gradle.api.tasks.compile.JavaCompile

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
    val isTfliteModule = project.name == "tflite_flutter"

    tasks.withType<JavaCompile>().configureEach {
        sourceCompatibility = if (isTfliteModule) {
            JavaVersion.VERSION_1_8.toString()
        } else {
            JavaVersion.VERSION_17.toString()
        }
        targetCompatibility = if (isTfliteModule) {
            JavaVersion.VERSION_1_8.toString()
        } else {
            JavaVersion.VERSION_17.toString()
        }
    }

    tasks.withType<KotlinJvmCompile>().configureEach {
        compilerOptions {
            jvmTarget.set(if (isTfliteModule) JvmTarget.JVM_1_8 else JvmTarget.JVM_17)
        }
    }
}

subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
