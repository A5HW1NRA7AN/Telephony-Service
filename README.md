# FreeSWITCH Telephony System - EKS/Kubernetes Deployment

This branch contains the deployment manifests and source code for running the FreeSWITCH telephony system on a Kubernetes cluster (such as Amazon EKS). It is designed to scale horizontally and deploy all stateful and stateless components inside Kubernetes pods.

---

## 1. Architecture Flow

```
                      SIP UDP 5060                           Internal Service Route
  [ Twilio Trunk ] ────────────────> [ Kong Ingress Proxy ] ─────────────────────────> [ FreeSWITCH Pod ]
                                       (UDP Routing)                                          │
                                                                                              │ Outbound ESL
                                                                                              ▼
  [ Lead Registry ] <── [ Lead-Service Pod ] <── [ Kafka Broker ] <── [ Event-Publisher Pod ] ┘
```

1. **Kong Ingress Controller**: Handles incoming SIP traffic on UDP port `5060` and routes it to the active FreeSWITCH pods.
2. **FreeSWITCH Pod**: Plays the welcome greeting and bridges the socket to the Event-Publisher.
3. **Event-Publisher**: Connects to the FreeSWITCH outbound socket, receives events, and publishes them to the Kafka broker.
4. **Lead-Service**: Consumes call hangup events from Kafka, logs them to PostgreSQL, and posts the lead payload to the external lead registry.

---

## 2. Directory Structure

```
.
├── infra/                      # Kubernetes deployment manifests
│   ├── apps/                   # Java services (event-publisher, lead-service)
│   ├── freeswitch/             # FreeSWITCH configmaps, deployments, and Dockerfile
│   ├── kafka/                  # Kafka cluster & topic definitions
│   ├── kong/                   # UDP ingress mapping for Kong
│   └── postgres/               # Postgres database and pgAdmin deployment
├── service/                    # Backend services source code
│   ├── event-publisher/        # Spring Boot ESL event-to-Kafka publisher
│   └── lead-service/           # Spring Boot Kafka-to-Registry lead ingestion service
├── .gitignore                  # Git ignore rules for Java/Kubernetes
└── README.md                   # This setup guide
```

---

## 3. Deployment Steps

### Step 1: Deploy Infrastructure
1. Apply database manifests:
   ```bash
   kubectl apply -f infra/postgres/
   ```
2. Apply Kafka broker manifests (assumes Strimzi Operator is installed):
   ```bash
   kubectl apply -f infra/kafka/
   ```

### Step 2: Build & Deploy FreeSWITCH
1. Navigate to the FreeSWITCH deployment directory:
   ```bash
   cd infra/freeswitch
   ```
2. Build the FreeSWITCH Docker image (baking in the custom greeting):
   ```bash
   docker build -t your-registry/freeswitch:latest .
   docker push your-registry/freeswitch:latest
   ```
3. Deploy FreeSWITCH configurations and deployment resources:
   ```bash
   kubectl apply -f freeswitch-configmap.yaml
   kubectl apply -f freeswitch-deployment.yaml
   kubectl apply -f freeswitch-service.yaml
   ```

### Step 3: Configure Ingress (Kong UDP Routing)
1. Configure UDP routing for SIP signaling:
   ```bash
   kubectl apply -f infra/kong/udp-ingress.yaml
   ```

### Step 4: Build & Deploy Java Backend Services
1. Build `event-publisher` and `lead-service` images:
   ```bash
   docker build -t your-registry/event-publisher:latest ./service/event-publisher
   docker build -t your-registry/lead-service:latest ./service/lead-service
   ```
2. Deploy manifests:
   ```bash
   kubectl apply -f infra/apps/
   ```

---

## 4. Verification & Testing

1. Check that all pods are running and healthy:
   ```bash
   kubectl get pods -A
   ```
2. Initiate a call to your Twilio phone number mapped to the Kong UDP LoadBalancer IP.
3. Check the lead service database or logs to verify that the call events were successfully processed.