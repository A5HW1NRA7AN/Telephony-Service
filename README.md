# FreeSWITCH Telephony System - Standalone EC2 Deployment

This branch contains the deployment files and source code for running the FreeSWITCH telephony system on a secure, standalone AWS EC2 stack. It utilizes a split-network topology with a public-facing Bastion host, a public-facing Nginx/SIP Proxy host, and a private FreeSWITCH application stack host running inside a custom VPC.

---

## 1. Network & Deployment Topology

```
                  SIP INVITE / UDP 5060                        NAT / DNAT Forwarding
 [ Twilio Trunk ] ──────────────────────> [ Nginx / SIP Proxy ] ────────────────────> [ FreeSWITCH (Private) ]
                                             (18.176.226.249)                            (10.0.1.143)
                                                                                               │
                                                                                               │ Outbound ESL
                                                                                               ▼
 [ Lead Registry ] <─── [ Lead-Service ] <─── [ Kafka Broker ] <─── [ Event-Publisher ] ◄─────┘
                         (PostgreSQL)
```

1. **Bastion Jump Host** (Public Subnet): Strictly handles secure SSH administration.
2. **Nginx / SIP Proxy** (Public Subnet): Exposes HTTP default routes for reverse-proxying web consoles, and implements `iptables` DNAT rules to route SIP (5060) and RTP (16384-32768) traffic into the private subnet.
3. **FreeSWITCH Host** (Private Subnet): Runs the core FreeSWITCH instance alongside PostgreSQL, pgAdmin, Kafka, Zookeeper, Event-Publisher, and Lead-Service in a host-network-bridged Docker Compose stack.

---

## 2. Directory Structure

```
.
├── config/                     # FreeSWITCH config files
│   └── freeswitch.xml          # Core dialplan, modules, and Sofia settings
├── infra/                      # Terraform & Deployment configurations
│   ├── copy_files.sh           # Syncs code files to the remote private host
│   ├── restart_services.sh     # Restarts remote Docker containers
│   ├── run_call.sh             # Triggers a local loopback call for testing
│   ├── run_db_query.sh         # Queries the remote database
│   ├── instances.tf            # Provisions EC2 instances and Nginx/NAT userdata
│   ├── main.tf                 # VPC definition and provider settings
│   ├── outputs.tf              # Outputs IPs and SSH commands
│   ├── security.tf             # Generates key pair and declares Security Groups
│   └── variables.tf            # Configurable Terraform inputs
├── service/                    # Backend services source code
│   ├── event-publisher/        # Spring Boot ESL event-to-Kafka publisher
│   └── lead-service/           # Spring Boot Kafka-to-Registry lead ingestion service
├── docker-compose.yml          # Runs backend services on the private host
├── .env.example                # Example environment file template
├── .gitignore                  # Git ignore rules for Java/Terraform
└── README.md                   # This setup & architecture guide
```

---

## 3. Deployment Steps

### Step 1: Provision AWS Infrastructure via Terraform
1. Navigate to the Terraform directory:
   ```bash
   cd infra
   ```
2. Initialize and apply the configurations:
   ```bash
   terraform init
   terraform apply -auto-approve
   ```
3. Record the outputs:
   - `proxy_public_ip` (Proxy Gateway Elastic IP)
   - `bastion_public_ip` (SSH Jump Host)
   - `freeswitch_private_ip` (Private Server IP)
   - `freeswitch-key.pem` (Automatically generated private key)

### Step 2: Configure Twilio Elastic SIP Trunking
1. Set up a Twilio Elastic SIP Trunk pointing to your `proxy_public_ip` as the Origination URI:
   `sip:<proxy_public_ip>:5060`
2. Bind a public phone number to the trunk (e.g. `+13613101995`).
3. Set Termination SIP URI to `coss-freeswitch.pstn.twilio.com` whitelisting the `proxy_public_ip`.

### Step 3: Deploy Services on the Private Host
1. Copy the code files to the private server via the helper script:
   ```bash
   ./copy_files.sh
   ```
2. SSH into the private instance:
   ```bash
   ssh -i freeswitch-key.pem -J admin@<bastion_public_ip> admin@<freeswitch_private_ip>
   ```
3. Navigate to `/home/admin/freeswitch` and create `.env` using `.env.example` as a template:
   ```bash
   cp .env.example .env
   nano .env # Set your database password, allowed lead context, and lead registry URL
   ```
4. Start the stack:
   ```bash
   docker compose up -d --build
   ```

---

## 4. Verification & Testing

1. Check that all 7 containers are healthy:
   ```bash
   docker ps --format "table {{.Names}}\t{{.Status}}"
   ```
2. Watch the FreeSWITCH CLI:
   ```bash
   docker exec -it telephony-freeswitch fs_cli -p CluSt3r@Esl#2026!
   ```
3. Make an inbound test call by dialing `+13613101995`. Verify the greeting sound plays and that the Event-Publisher receives the call, publishes it to Kafka, and the Ingestion Service posts it to the lead registry.
4. Run the database query tool locally to verify that the lead has been successfully logged:
   ```bash
   ./run_db_query.sh
   ```