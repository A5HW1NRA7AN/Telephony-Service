pipeline {
    agent any

    environment {
        AWS_REGION     = 'ap-northeast-1'
        AWS_ACCOUNT_ID = '379220350808'
        ECR_REGISTRY   = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
        
        LEAD_SERVICE_REPO    = 'freeswitch-lead-service-ec2'
        EVENT_PUBLISHER_REPO = 'freeswitch-event-publisher-ec2'
        FREESWITCH_REPO      = 'freeswitch-freeswitch-ec2'
        
        BASTION_IP          = '13.112.221.231'
        PRIVATE_SERVER_IP   = '10.0.1.143'
        
        // Jenkins credentials IDs
        AWS_CREDENTIALS_ID  = 'aws-credentials'
        SSH_CREDENTIALS_ID  = 'ssh-private-key'
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Build Java Artifacts') {
            steps {
                sh 'mvn clean package -DskipTests -f service/lead-service/pom.xml'
                sh 'mvn clean package -DskipTests -f service/event-publisher/pom.xml'
            }
        }

        stage('Docker Build & Tag') {
            steps {
                script {
                    sh "docker build -t ${ECR_REGISTRY}/${LEAD_SERVICE_REPO}:${BUILD_NUMBER} -t ${ECR_REGISTRY}/${LEAD_SERVICE_REPO}:latest ./service/lead-service"
                    sh "docker build -t ${ECR_REGISTRY}/${EVENT_PUBLISHER_REPO}:${BUILD_NUMBER} -t ${ECR_REGISTRY}/${EVENT_PUBLISHER_REPO}:latest ./service/event-publisher"
                    sh "docker build -t ${ECR_REGISTRY}/${FREESWITCH_REPO}:${BUILD_NUMBER} -t ${ECR_REGISTRY}/${FREESWITCH_REPO}:latest ./infra/freeswitch"
                }
            }
        }

        stage('ECR Push') {
            steps {
                withCredentials([[
                    $class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: env.AWS_CREDENTIALS_ID,
                    accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                    secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
                ]]) {
                    sh "aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_REGISTRY}"
                    
                    sh "docker push ${ECR_REGISTRY}/${LEAD_SERVICE_REPO}:${BUILD_NUMBER}"
                    sh "docker push ${ECR_REGISTRY}/${LEAD_SERVICE_REPO}:latest"
                    
                    sh "docker push ${ECR_REGISTRY}/${EVENT_PUBLISHER_REPO}:${BUILD_NUMBER}"
                    sh "docker push ${ECR_REGISTRY}/${EVENT_PUBLISHER_REPO}:latest"
                    
                    sh "docker push ${ECR_REGISTRY}/${FREESWITCH_REPO}:${BUILD_NUMBER}"
                    sh "docker push ${ECR_REGISTRY}/${FREESWITCH_REPO}:latest"
                }
            }
        }

        stage('Deploy to EC2') {
            steps {
                withCredentials([
                    sshUserPrivateKey(credentialsId: env.SSH_CREDENTIALS_ID, keyFileVariable: 'SSH_KEY_FILE', usernameVariable: 'SSH_USER')
                ]) {
                    script {
                        // 1. Get ECR login password
                        def ecrPassword = sh(script: "aws ecr get-login-password --region ${AWS_REGION}", returnStdout: true).trim()
                        
                        // Copy SSH key to Bastion for tunneling
                        sh """
                            scp -o StrictHostKeyChecking=no -i \${SSH_KEY_FILE} \${SSH_KEY_FILE} ubuntu@\${BASTION_IP}:/home/ubuntu/.ssh/id_rsa
                            ssh -o StrictHostKeyChecking=no -i \${SSH_KEY_FILE} ubuntu@\${BASTION_IP} "chmod 600 /home/ubuntu/.ssh/id_rsa"
                        """
                        
                        // 2. Log in remote docker to ECR via Bastion tunnel
                        sh """
                            ssh -o StrictHostKeyChecking=no -i \${SSH_KEY_FILE} ubuntu@\${BASTION_IP} \
                                "ssh -o StrictHostKeyChecking=no -i /home/ubuntu/.ssh/id_rsa ubuntu@\${PRIVATE_SERVER_IP} \
                                 'echo ${ecrPassword} | docker login --username AWS --password-stdin ${ECR_REGISTRY}'"
                        """
                        
                        // 3. Create deployment directory on private server
                        sh """
                            ssh -o StrictHostKeyChecking=no -i \${SSH_KEY_FILE} ubuntu@\${BASTION_IP} \
                                "ssh -o StrictHostKeyChecking=no -i /home/ubuntu/.ssh/id_rsa ubuntu@\${PRIVATE_SERVER_IP} \
                                 'mkdir -p /home/ubuntu/freeswitch'"
                        """
                        
                        // 4. Copy docker-compose.yml and config/freeswitch.xml to the remote host
                        sh """
                            scp -o StrictHostKeyChecking=no -i \${SSH_KEY_FILE} docker-compose.yml ubuntu@\${BASTION_IP}:/home/ubuntu/docker-compose.yml
                            ssh -o StrictHostKeyChecking=no -i \${SSH_KEY_FILE} ubuntu@\${BASTION_IP} \
                                "scp -o StrictHostKeyChecking=no -i /home/ubuntu/.ssh/id_rsa /home/ubuntu/docker-compose.yml ubuntu@\${PRIVATE_SERVER_IP}:/home/ubuntu/freeswitch/docker-compose.yml"
                            
                            ssh -o StrictHostKeyChecking=no -i \${SSH_KEY_FILE} ubuntu@\${BASTION_IP} "mkdir -p /home/ubuntu/config"
                            scp -o StrictHostKeyChecking=no -i \${SSH_KEY_FILE} config/freeswitch.xml ubuntu@\${BASTION_IP}:/home/ubuntu/config/freeswitch.xml
                            ssh -o StrictHostKeyChecking=no -i \${SSH_KEY_FILE} ubuntu@\${BASTION_IP} \
                                "ssh -o StrictHostKeyChecking=no -i /home/ubuntu/.ssh/id_rsa ubuntu@\${PRIVATE_SERVER_IP} 'mkdir -p /home/ubuntu/freeswitch/config' && \
                                 scp -o StrictHostKeyChecking=no -i /home/ubuntu/.ssh/id_rsa /home/ubuntu/config/freeswitch.xml ubuntu@\${PRIVATE_SERVER_IP}:/home/ubuntu/freeswitch/config/freeswitch.xml"
                        """
                        
                        // 5. Pull and recreate containers
                        sh """
                            ssh -o StrictHostKeyChecking=no -i \${SSH_KEY_FILE} ubuntu@\${BASTION_IP} \
                                "ssh -o StrictHostKeyChecking=no -i /home/ubuntu/.ssh/id_rsa ubuntu@\${PRIVATE_SERVER_IP} \
                                 'cd /home/ubuntu/freeswitch && \
                                  ECR_REGISTRY=${ECR_REGISTRY} \
                                  ECR_REPOSITORY_LEAD_SERVICE=${LEAD_SERVICE_REPO} \
                                  ECR_REPOSITORY_EVENT_PUBLISHER=${EVENT_PUBLISHER_REPO} \
                                  ECR_REPOSITORY_FREESWITCH=${FREESWITCH_REPO} \
                                  IMAGE_TAG=${BUILD_NUMBER} \
                                  docker compose pull && \
                                  ECR_REGISTRY=${ECR_REGISTRY} \
                                  ECR_REPOSITORY_LEAD_SERVICE=${LEAD_SERVICE_REPO} \
                                  ECR_REPOSITORY_EVENT_PUBLISHER=${EVENT_PUBLISHER_REPO} \
                                  ECR_REPOSITORY_FREESWITCH=${FREESWITCH_REPO} \
                                  IMAGE_TAG=${BUILD_NUMBER} \
                                  docker compose up -d'"
                        """
                    }
                }
            }
        }
    }

    post {
        always {
            sh "docker rmi ${ECR_REGISTRY}/${LEAD_SERVICE_REPO}:${BUILD_NUMBER} || true"
            sh "docker rmi ${ECR_REGISTRY}/${EVENT_PUBLISHER_REPO}:${BUILD_NUMBER} || true"
            sh "docker rmi ${ECR_REGISTRY}/${FREESWITCH_REPO}:${BUILD_NUMBER} || true"
        }
    }
}
