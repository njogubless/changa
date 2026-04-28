

import 'package:changa/core/themes/app_theme.dart';
import 'package:flutter/material.dart';

enum PolicyType { privacyPolicy, termsOfService }

class PolicyViewerScreen extends StatelessWidget {
  final PolicyType type;
  const PolicyViewerScreen({super.key, required this.type});

  String get _title => switch (type) {
        PolicyType.privacyPolicy => 'Privacy Policy',
        PolicyType.termsOfService => 'Terms of Service',
      };

  String get _content => switch (type) {
        PolicyType.privacyPolicy => _privacyPolicyText,
        PolicyType.termsOfService => _termsOfServiceText,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.cream,
        elevation: 0,
        title: Text(
          _title,
          style: AppTextStyles.h4.copyWith(color: AppColors.forest),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.forest),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 48),
        child: Text(
          _content,
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.charcoal,
            height: 1.7,
          ),
        ),
      ),
    );
  }
}

const _privacyPolicyText = '''
PRIVACY POLICY
Last updated: April 2025

[Copy all
Privacy Policy

Changa · Last updated: April 2025 · Effective date: April 2025

Changa is committed to protecting your personal data in accordance with the Kenya Data Protection Act, 2019 and its associated regulations. This policy explains what we collect, why we collect it, and your rights over it.
1. Who we are

Changa is a mobile-first chama contribution platform operating in Kenya. We help groups of individuals pool and manage money together through M-Pesa and other mobile money channels.

Data Controller: Changa (insert company legal name)
Contact: privacy@changa.co.ke
Registered address: [Insert address], Nairobi, Kenya

2. Data we collect

We collect only the data necessary to provide and improve our services:

Identity data: Full name
Contact data: Email address, M-Pesa phone number (254XXXXXXXXX format)
Authentication data: Hashed passwords (never stored in plain text)
Financial data: Contribution history, chama membership records, M-Pesa transaction references
Usage data: App activity logs, device type, operating system
Communications: In-app messages and notifications you send or receive

We do not collect biometric data, government ID numbers, or credit scores.

3. How we use your data
To create and manage your account
To process M-Pesa contributions and disbursements within your chama
To send you transaction confirmations and account notifications
To resolve disputes and investigate fraud
To comply with legal obligations under Kenyan law
To improve app performance (using aggregated, anonymised analytics)

We do not use your data for third-party advertising.

4. Legal basis for processing
Contract performance: Processing your contributions and managing your account
Legitimate interests: Security monitoring and fraud prevention
Legal obligation: Compliance with the Data Protection Act, 2019 and CBK guidelines
Consent: Marketing communications (only if you opt in)
5. Who we share your data with

We share your data only where strictly necessary:

Safaricom / Airtel: Your M-Pesa number is passed to the relevant mobile money provider solely to process transactions you initiate
Cloud infrastructure: Data is stored on secure servers (currently [insert provider, e.g. AWS / Google Cloud]) with encryption at rest and in transit
Legal authorities: Where required by a valid court order or applicable Kenyan law

We do not sell your data. We do not share your data with advertisers.

6. Data retention
Active account data: retained while your account is active
Transaction records: retained for 7 years (as required by Kenyan financial regulations)
Deleted accounts: personal data erased within 30 days of account deletion, except where we have a legal obligation to retain it
7. Data security

We protect your data using industry-standard safeguards:

Passwords are hashed using bcrypt before storage
All data in transit uses TLS 1.2 or higher
Database access is restricted by role-based access control
We conduct regular security reviews

No system is 100% secure. If a breach occurs that affects your rights, we will notify you and the Office of the Data Protection Commissioner within 72 hours as required by law.

8. Your rights under the Data Protection Act, 2019

You have the right to:

Access a copy of the personal data we hold about you
Rectify inaccurate or incomplete data
Erase your data (subject to legal retention requirements)
Object to processing based on legitimate interests
Data portability — receive your data in a machine-readable format
Withdraw consent at any time (for processing based on consent)

To exercise any of these rights, email us at privacy@changa.co.ke. We will respond within 21 days. If you are unsatisfied with our response, you may lodge a complaint with the Office of the Data Protection Commissioner of Kenya.

9. Children

Changa is not intended for persons under 18 years of age. We do not knowingly collect personal data from minors. If you believe a minor has created an account, please contact us immediately and we will remove their data.

10. Changes to this policy

We may update this Privacy Policy from time to time. We will notify you of material changes via in-app notification or email at least 14 days before the change takes effect. Continued use of Changa after that date constitutes acceptance of the updated policy.

11. Contact us

For any privacy-related questions or requests:
Email: privacy@changa.co.ke
Address: [Insert address], Nairobi, Kenya]
''';

const _termsOfServiceText = '''
TERMS OF SERVICE
Last updated: April 2025

[Copy all
Terms of Service

Changa · Last updated: April 2025 · Effective date: April 2025

By creating a Changa account you agree to these Terms. Please read them carefully. These Terms are governed by the laws of the Republic of Kenya.
1. About Changa

Changa is a platform that enables groups of people ("chamas") to contribute money, track balances, and manage collective finances using M-Pesa and other mobile money services. Changa is a facilitator — we are not a bank, a lender, or a licensed financial institution.

2. Eligibility
You must be at least 18 years old to use Changa
You must be a resident of Kenya or a jurisdiction where Changa services are available
You must have a valid M-Pesa or supported mobile money account
You must not have been previously banned from Changa
3. Account responsibilities

You are responsible for:

Providing accurate, current, and complete registration information
Keeping your password secure and not sharing it with anyone
All activity that occurs under your account
Notifying us immediately at support@changa.co.ke if you suspect unauthorised access
Ensuring your registered M-Pesa number is correct — Changa is not liable for contributions sent to a wrong number due to user error
4. Chama rules and member conduct

When you create or join a chama on Changa, you agree that:

Chama owners set and enforce their own contribution rules; Changa merely provides the platform
Disputes between chama members are the responsibility of the members themselves; Changa may assist with information but is not an arbitrator
You will not use Changa to collect money under false pretences or for fraudulent purposes
You will not create multiple accounts to manipulate contribution records
You will treat fellow members with respect; harassment or abuse will result in account suspension
5. Payments and M-Pesa transactions
All monetary transactions are processed through M-Pesa (Safaricom) or other mobile money providers; Changa does not hold, transfer, or store funds on your behalf
Changa is not responsible for delays, failures, or errors caused by Safaricom, Airtel Money, or any other third-party payment provider
Transaction fees charged by your mobile money provider are separate from any Changa service fees and are the user's responsibility
Changa service fees (if any) will be clearly disclosed before any charge is applied
Completed M-Pesa transactions cannot be reversed by Changa; contact Safaricom directly for reversal requests
6. Prohibited uses

You may not use Changa to:

Launder money or finance illegal activities
Collect funds through deception, misrepresentation, or fraud
Impersonate another person or organisation
Attempt to reverse-engineer, hack, or disrupt Changa's systems
Violate any applicable Kenyan law or regulation
7. Intellectual property

The Changa name, logo, app design, and underlying technology are owned by Changa and protected by Kenyan intellectual property law. You may not copy, modify, or distribute them without written permission.

You retain ownership of any content you create on the platform (chama names, descriptions, messages). By posting content, you grant Changa a non-exclusive licence to display that content to the relevant chama members.

8. Disclaimers and limitation of liability

Changa is provided "as is." To the extent permitted by law:

We do not guarantee that the app will be error-free or uninterrupted
We are not liable for losses arising from M-Pesa outages, network failures, or third-party service disruptions
We are not liable for disputes between chama members
Our total liability to you for any claim arising from your use of Changa shall not exceed the total fees (if any) you paid to Changa in the 12 months preceding the claim
9. Account termination

You may delete your account at any time from the app settings. We may suspend or terminate your account without notice if we believe you have:

Violated these Terms or our Privacy Policy
Engaged in fraudulent activity
Posed a security risk to Changa or other users

Upon termination, your access to the app ceases immediately. Transaction records may be retained as required by law.

10. Changes to these Terms

We may update these Terms from time to time. We will notify you via in-app notification or email at least 14 days before material changes take effect. Continued use of Changa after that date constitutes acceptance of the updated Terms.

11. Governing law and disputes

These Terms are governed by and construed in accordance with the laws of the Republic of Kenya. Any disputes shall first be subject to good-faith negotiation. If unresolved, disputes shall be referred to the courts of competent jurisdiction in Nairobi, Kenya.

12. Contact us

For any questions about these Terms:
Email: support@changa.co.ke
Address: [Insert address], Nairobi, Kenya]
''';