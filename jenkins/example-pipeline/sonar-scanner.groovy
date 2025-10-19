podTemplate(yaml: """
apiVersion: v1
kind: Pod
metadata:
  name: sonar-scanner
spec:
  containers:
  - name: sonar-scanner
    image: sonarsource/sonar-scanner-cli:latest
    tty: true
    command:
    - cat
"""
) {
    node(POD_LABEL) {
        container('sonar-scanner') {
            withSonarQubeEnv(installationName: 'BRM-Sonarqube-Clone') {
                sh "mkdir -p org/hello"
                sh "echo \"package org.hello; public class Main { public static void main(String[] args) { new Random().next(4); }}\" > org/hello/hello.java"
                sh "sonar-scanner -Dsonar.projectKey=callback_test-2 -Dsonar.sources=."
            }
            timeout(time: 2, unit: 'MINUTES') { // Just in case something goes wrong, pipeline will be killed after a timeout
                def qg = waitForQualityGate() // Reuse taskId previously collected by withSonarQubeEnv
                if (qg.status != 'OK') {
                    error "Pipeline aborted due to quality gate failure: ${qg.status}"
                }
            }
        }
    }
}