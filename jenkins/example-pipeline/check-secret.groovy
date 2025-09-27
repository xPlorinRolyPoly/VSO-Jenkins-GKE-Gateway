pipeline {
    agent {
        kubernetes {
            yaml """
apiVersion: v1
kind: Pod
spec:
  containers:
  - name: jenkins-agent
    image: jenkins/inbound-agent:latest
    command:
    - cat
    tty: true
    resources:
      requests:
        memory: "256Mi"
        cpu: "100m"
      limits:
        memory: "512Mi"
        cpu: "500m"
"""
        }
    }
    
    stages {
        stage('Check Secret') {
            steps {
                container('jenkins-agent') {
                    script {
                        // Let's try different credential IDs to see what's available
                        echo "=== Testing different credential configurations ==="
                        
                        // Test 1: Try the exact credential ID from Jenkins config
                        try {
                            withCredentials([string(credentialsId: 'alpana-secret-key', variable: 'ALPANA_SECRET')]) {
                                echo "✅ alpana-secret-key credential exists"
                                if (env.ALPANA_SECRET?.trim()) {
                                    echo "✅ Credential length: ${env.ALPANA_SECRET.length()}"
                                    echo "✅ Credential hash: ${env.ALPANA_SECRET.hashCode()}"
                                } else {
                                    echo "❌ Credential is empty"
                                }
                            }
                        } catch (Exception e) {
                            echo "❌ alpana-secret-key failed: ${e.message}"
                        }
                    }
                }
            }
        }
    }
    
    post {
        always {
            echo "Pipeline completed. Remember to secure your Jenkins credentials!"
        }
        success {
            echo "✅ Successfully retrieved and displayed credential information"
        }
        failure {
            echo "❌ Failed to retrieve credential information"
        }
    }
}