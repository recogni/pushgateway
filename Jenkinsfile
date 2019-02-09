scmVars = [:]
activeStageName = ""
dockerImages = []

pipeline {
    agent any

    options {
        skipDefaultCheckout()
    }

    environment {
        GCP_PROJECT_ID = sh(script: "gcloud config get-value project", returnStdout: true).trim()
        DOCKER_REPOSITORY = "us.gcr.io"
        SLACK_CHANNEL = "dev-automation"
    }

    stages {
        stage("Checkout") {
            steps {
                script {
                    activeStageName = env.STAGE_NAME

                    scmVars = checkout(scm)

                    scmVars.GIT_URL = scmVars.GIT_URL.replaceFirst(/\.git$/, "")
                    scmVars.GIT_REPOSITORY = scmVars.GIT_URL.replaceFirst(/^[a-z]+:\/\/[^\/]*\//, "")
                    scmVars.GIT_AUTHOR = sh(script: "${GIT_EXEC_PATH}/git log -1 --pretty=%an ${scmVars.GIT_COMMIT}", returnStdout: true).trim()
                    scmVars.GIT_MESSAGE = sh(script: "${GIT_EXEC_PATH}/git log -1 --pretty=%s ${scmVars.GIT_COMMIT}", returnStdout: true).trim()

                    scmVars.each { k, v ->
                         env."${k}" = "${v}"
                    }
                }
            }
        }

        stage("Build") {
            steps {
                sh("gcloud auth configure-docker --quiet")

                script {
                    activeStageName = env.STAGE_NAME

                    docker.withRegistry("https://${env.DOCKER_REPOSITORY}") {
                        dockerImage = docker.build("${env.DOCKER_REPOSITORY}/${env.GCP_PROJECT_ID}/pushgateway:${env.BUILD_ID}",
                                                   " --no-cache" +
                                                   " --pull" +
                                                   " .")

                        dockerImages << dockerImage

                        dockerImage.push("${env.BUILD_ID}-${scmVars.GIT_COMMIT.substring(0,8)}")

                        if (scmVars.GIT_BRANCH == "recogni") {
                            dockerImage.push("latest")
                        }
                    }
                }
            }
        }
    }

    post {
        always {
            script {
                dockerImages.each() { dockerImage ->
                    sh("docker image rm -f \$(docker image ls --format '{{.ID}}' ${dockerImage.id})")
                }

                sh('''#!/bin/bash -xe
                    docker image prune -f
                    docker container prune -f --filter 'until=24h'
                   ''')
            }
        }

        success {
            sendSlackMessage("Success", "good")
        }

        failure {
            sendSlackMessage("Failure (${activeStageName})", "danger")
        }
    }
}

void sendSlackMessage(String result = "Success", String color = "good") {
    def author = scmVars.GIT_AUTHOR.split().first().toLowerCase()
    def message = "${result}: ${author.capitalize()}'s build <${currentBuild.absoluteUrl}|${currentBuild.displayName}> in <${scmVars.GIT_URL}|${scmVars.GIT_REPOSITORY}> (<${scmVars.GIT_URL}/commit/${scmVars.GIT_COMMIT}|${scmVars.GIT_COMMIT.substring(0,8)}> on <${scmVars.GIT_URL}/tree/${scmVars.GIT_BRANCH}|${scmVars.GIT_BRANCH}>)\n• ${scmVars.GIT_MESSAGE}"

    dockerImages.collect() { dockerImage ->
        dockerImage.imageName().split(":").first()
    }.toSet().each() { imageName ->
        message += "\nPushed: <https://console.cloud.google.com/gcr/images/${env.GCP_PROJECT_ID}/${env.DOCKER_REPOSITORY.replaceFirst(/\.gcr\.io$/, "")}/${imageName.split("/")[-1]}|${imageName}:*>"
    }

    if (scmVars.GIT_BRANCH =~ /\b(wip)\b/) {
        channel = "@" + getMatchingSlackUsername(author)
    }
    else {
        channel = env.SLACK_CHANNEL
    }

    slackSend(channel: channel,
              color: color,
              message: message)
}

import static org.apache.commons.lang3.StringUtils.getLevenshteinDistance

@NonCPS
String getMatchingSlackUsername(String author) {
    userName =
        ["berend", "eugene", "gilles", "martin", "shaba"].sort { a, b ->
            getLevenshteinDistance(author, a) <=> getLevenshteinDistance(author, b)
        }.first()

    return userName
}
