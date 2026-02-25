// Jenkinsfile — sample pipeline for the playground repo itself
// This can be used if you point a Jenkins pipeline job at this repo.

pipeline {
    agent { label 'ssh-agent || jnlp-agent' }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Environment Info') {
            steps {
                echo "Running on node: ${env.NODE_NAME}"
                sh 'hostname'
                sh 'java -version'
                sh 'uname -a'
            }
        }

        stage('Build') {
            steps {
                echo 'No build step defined yet — add your own!'
                sh 'ls -la'
            }
        }

        stage('Test') {
            steps {
                echo 'No tests defined yet — add your own!'
            }
        }
    }

    post {
        success {
            echo 'Pipeline completed successfully!'
        }
        failure {
            echo 'Pipeline failed!'
        }
        always {
            echo "Finished on node: ${env.NODE_NAME}"
            cleanWs()
        }
    }
}
