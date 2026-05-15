# Telephony Infrastructure Setup Guide

This guide will walk you through setting up your Asterisk PBX on AWS, configuring your SIP provider (like Twilio), and spinning up the local Java Lead Service.

## Phase 1: Deploy Asterisk PBX via Terraform

We use Terraform to automatically spin up an AWS EC2 instance, install FreePBX, configure the firewall, and apply all SIP NAT and routing configurations.

1. **Navigate to the infra directory**:
   ```bash
   cd infra
   ```

2. **Configure your Variables**:
   Copy the example variables file:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```
   Open `terraform.tfvars` and edit the values. You *must* define:
   - `ami_username` and `ami_password` (Credentials for the Java service to connect to Asterisk)
   - `sip_provider_domain` (e.g., `your-domain.pstn.twilio.com`)
   - `inbound_did` (e.g., `+13364904091`)

3. **Deploy**:
   Ensure you have AWS credentials configured locally, then run:
   ```bash
   terraform init
   terraform apply
   ```
   *Note: This process takes about ~10-15 minutes because it installs FreePBX from scratch. Grab a coffee!*

4. **Upload your Greeting**:
   Once Terraform finishes, it will output the PBX's IP address. Upload your custom `greeting.mp3` or `.wav` to the PBX:
   ```bash
   scp -i asterisk-key.pem greeting.mp3 admin@<PBX_IP>:/tmp/
   ssh -i asterisk-key.pem admin@<PBX_IP> "sudo cp /tmp/greeting.mp3 /var/lib/asterisk/sounds/custom/greeting.mp3 && sudo chown asterisk:asterisk /var/lib/asterisk/sounds/custom/greeting.mp3"
   ```

---

## Phase 2: Configure Your SIP Provider (Example: Twilio)

You need to tell your SIP provider where to route incoming calls.

1. **Create a SIP Trunk**: In the Twilio Console, go to Elastic SIP Trunking -> Trunks -> Create new SIP Trunk.
2. **Origination**: Add a new Origination URI pointing to your new PBX IP:
   - URI: `sip:<PBX_IP>`
3. **Termination**: Create a Termination SIP Domain matching what you put in `terraform.tfvars` (e.g., `your-domain.pstn.twilio.com`). Add an IP Access Control List (ACL) that allows traffic from your PBX's IP address.
4. **Numbers**: Assign your purchased Twilio phone number to the Trunk.

---

## Phase 3: Start the Lead Service

The Lead Service is a Dockerized Spring Boot application that connects to Asterisk, listens for hangups, and submits leads.

1. **Navigate to the root directory**:
   ```bash
   cd ..
   ```

2. **Configure the Environment**:
   Copy the example environment file:
   ```bash
   cp .env.example .env
   ```
   Open `.env` and fill in the fields using the outputs from Terraform:
   - `AMI_HOST`: Your PBX's Public IP
   - `AMI_USERNAME` / `AMI_SECRET`: The credentials you set in Terraform
   - `LEAD_REGISTRY_URL`: The external API endpoint to send leads to (e.g., `http://your-registry:8080/leads/v1/initiate`)

3. **Start the Services**:
   Start the Postgres database, pgAdmin, and the Java Lead Service:
   ```bash
   docker compose up -d --build
   ```

4. **Verify**:
   Watch the logs to confirm the service successfully connects to Asterisk:
   ```bash
   docker compose logs lead-service -f
   ```
   You should see: `AMI login accepted`.

---

## Phase 4: Test & Monitor

1. **Make a Call**: Dial your Twilio number from your cell phone. You should hear the greeting play, and the call will hang up automatically.
2. **Check Logs**: The `lead-service` logs should show a successful JSON payload dispatch to your registry.
3. **View the Database**:
   - Open pgAdmin in your browser at `http://localhost:5050`
   - Login with the credentials from your `.env` file (default: `admin@admin.com` / `admin`).
   - Add the server: Host `postgres`, DB `lead_db`, User `lead_user`.
   - Query the `telephony_call_lead_ingest_log` table to see a history of all intercepted calls.
