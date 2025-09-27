podTemplate(yaml: """
apiVersion: v1
kind: Pod
metadata:
  name: hello-world
spec:
  containers:
  - name: alpine
    image: alpine:latest
    tty: true
    command:
    - cat
"""
) {
    node(POD_LABEL) {
        container('alpine') {
            sh 'echo "Hello, World!"'
        }
    }
}