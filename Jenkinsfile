pipeline {
    agent any

    options {
        disableConcurrentBuilds()
    }

    triggers {
        cron('TZ=Asia/Kolkata\nH 9 25 * *')
    }

    parameters {
        choice(name: 'TARGET', choices: ['mps-demo', 'mps-prod'],
               description: 'Namespace for a manual deployment')
        string(name: 'IMAGE_TAG',
               defaultValue: '4b0e031f43fbe6b0ed0ab5c1142d306c856fc886',
               description: 'Git commit SHA published to Docker Hub')
    }

    stages {
        stage('Check release rules') {
            steps {
                script {
                    def scheduled = currentBuild.getBuildCauses(
                        'hudson.triggers.TimerTrigger$TimerTriggerCause'
                    ).size() > 0
                    env.DEPLOY_NAMESPACE = scheduled ? 'mps-prod' : params.TARGET
                    env.RELEASE_TAG = params.IMAGE_TAG.trim()

                    if (!(env.RELEASE_TAG ==~ /[0-9a-f]{40}/)) {
                        error('Enter the full Git commit SHA from Docker Hub.')
                    }

                    def day = sh(
                        script: 'TZ=Asia/Kolkata date +%d',
                        returnStdout: true
                    ).trim()
                    if (env.DEPLOY_NAMESPACE == 'mps-prod' && day != '25') {
                        error('Production releases are allowed only on the 25th IST.')
                    }
                }
            }
        }

        stage('Deploy to EKS') {
            steps {
                sh '''#!/bin/sh
set -eu

kubectl -n "$DEPLOY_NAMESPACE" apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: website-mps
spec:
  replicas: 2
  selector:
    matchLabels:
      app: website-mps
  template:
    metadata:
      labels:
        app: website-mps
    spec:
      imagePullSecrets:
        - name: dockerhub-pull
      containers:
        - name: website
          image: docker.io/danishmohd/mps-devops-website:$RELEASE_TAG
          ports:
            - containerPort: 80
          readinessProbe:
            httpGet:
              path: /
              port: 80
EOF

kubectl -n "$DEPLOY_NAMESPACE" rollout status deployment/website-mps --timeout=5m

apply_service() {
  service_namespace=$1
  service_type=$2
  node_port=''
  if [ "$service_type" = NodePort ]; then
    node_port='      nodePort: 30008'
  fi
  kubectl -n "$service_namespace" apply -f - <<EOF
apiVersion: v1
kind: Service
metadata:
  name: website-mps
spec:
  type: $service_type
  selector:
    app: website-mps
  ports:
    - port: 80
      targetPort: 80
$node_port
EOF
}

get_node_port() {
  kubectl -n "$1" get service website-mps --ignore-not-found \
    -o jsonpath='{.spec.ports[0].nodePort}'
}

if [ "$DEPLOY_NAMESPACE" = mps-prod ]; then
  demo_port=$(get_node_port mps-demo)
  if [ "$demo_port" = 30008 ]; then
    apply_service mps-demo ClusterIP
  fi
  if ! apply_service mps-prod NodePort; then
    if [ "$demo_port" = 30008 ]; then
      apply_service mps-demo NodePort
    fi
    exit 1
  fi
elif [ "$(get_node_port mps-prod)" = 30008 ]; then
  apply_service mps-demo ClusterIP
else
  apply_service mps-demo NodePort
fi

kubectl -n "$DEPLOY_NAMESPACE" get deployment,pods,service -o wide
'''
            }
        }
    }
}
