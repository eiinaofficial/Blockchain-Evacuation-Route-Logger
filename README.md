# 🛡️ Blockchain Evacuation Route Logger

Welcome to a decentralized system for securely logging and verifying evacuation routes during conflicts or disasters! Built on the Stacks blockchain with Clarity smart contracts, this project enables authorities to immutably record safe paths while allowing locals to verify them via mobile apps, ensuring trustworthy navigation and reducing risks in crisis situations.

## ✨ Features

🗺️ Register evacuation routes with geospatial hashes and timestamps  
🔒 Immutable proof of route creation and updates by verified authorities  
📱 App-friendly verification for locals to confirm route validity  
⚠️ Dispute mechanism for reporting inaccurate or outdated routes  
👥 Authority management to onboard trusted organizations  
📊 Audit trails for all route changes and verifications  
💰 Incentive rewards for community validations and reports  
🛡️ Access controls to prevent unauthorized modifications  

## 🛠 How It Works

**For Authorities (e.g., Government or NGO Officials)**

- Generate a SHA-256 hash of route details (coordinates, descriptions, timestamps)  
- Call `register-route` in the Route Registration Contract with:  
  - Route hash  
  - Description and estimated safety level  
  - Geospatial boundaries  
- Use the Authority Management Contract to get verified status before registering  
- Update routes via `update-route` if conditions change, with immutable logging  

**For Locals (Via Mobile Apps)**

- Query `get-route-details` from the Verification Contract using a route ID  
- Call `verify-route` to confirm the route's authenticity against the blockchain timestamp  
- Report issues with `submit-dispute` in the Dispute Resolution Contract, earning rewards if validated  
- Access audit logs via the Audit Trail Contract for full transparency  

**Smart Contracts Overview (7 Contracts in Total)**

This project leverages 7 interconnected Clarity smart contracts on Stacks for robustness:  

1. **Authority Management Contract**: Handles registration and verification of authorities (e.g., NGOs) who can log routes.  
2. **Route Registration Contract**: Core contract for hashing and storing new evacuation routes with timestamps.  
3. **Route Update Contract**: Manages secure updates to routes, ensuring immutability of original logs.  
4. **Verification Contract**: Allows users to query and verify route details in real-time.  
5. **Dispute Resolution Contract**: Processes user reports on routes, with voting or authority review mechanisms.  
6. **Audit Trail Contract**: Logs all actions (registrations, updates, verifications) for tamper-proof history.  
7. **Incentive Rewards Contract**: Distributes STX tokens as rewards for valid verifications and dispute resolutions to encourage participation.  

Boom! Routes are now verifiably safe and accessible, saving lives in conflicts. Deploy on Stacks testnet to get started.