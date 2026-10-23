# iPhone builds from Windows

The Player app uses `com.kocourt.player` (display name **KoCourt**). The Owner
app uses `com.kocourt.owner` (**KoCourt Owner**). Both target iOS 13 or later;
dependencies may raise that minimum in future. The two apps use the existing
KoCourt logo, with opaque white backgrounds for App Store icons.

## Before Apple enrollment

Push this branch to GitHub and open a pull request, or select **Actions → iOS
Build and TestFlight → Run workflow**, leaving **upload_testflight** unchecked.
The macOS runner analyzes/tests each app and compiles an unsigned release build.
Unsigned builds cannot be installed on an iPhone. macOS runner usage is subject
to your GitHub plan and billing settings.

## One-time Apple setup

1. Enroll in the Apple Developer Program and accept the required agreements.
2. In Certificates, Identifiers & Profiles, register explicit App IDs for both
   bundle IDs above. Create two iOS app records in App Store Connect, selecting
   the matching IDs. App names must be available; SKUs can be `kocourt-player`
   and `kocourt-owner`.
3. Create an **Apple Distribution** certificate with a CSR. Keep its private
   key. On Windows, OpenSSL can create the key and CSR:

   ```powershell
   openssl req -new -newkey rsa:2048 -nodes -keyout distribution.key -out distribution.csr
   ```

   Upload the CSR in Apple's certificate portal and download `distribution.cer`.
   Convert it and export a password-protected PKCS#12 file:

   ```powershell
   openssl x509 -inform DER -in distribution.cer -out distribution.pem
   openssl pkcs12 -export -inkey distribution.key -in distribution.pem -out distribution.p12
   ```

   Run these commands in a secure folder outside this repository. The `.p12`
   password will be a GitHub secret. Renew certificates/profiles before expiry.
4. Create one **App Store Connect distribution provisioning profile** per app,
   using that same certificate, and download both `.mobileprovision` files.
   Do not use development or Ad Hoc profiles.
5. In App Store Connect → Users and Access → Integrations → App Store Connect
   API, create a team API key with **App Manager** access. Record its key ID and
   issuer ID and download its `.p8` private key (download is available once).
6. In the GitHub repository's **Settings → Secrets and variables → Actions**,
   add the following repository secrets:

   | Secret | Value |
   | --- | --- |
   | `IOS_TEAM_ID` | Your 10-character Apple Developer Team ID |
   | `IOS_CERTIFICATE_BASE64` | Base64 of `distribution.p12` |
   | `IOS_CERTIFICATE_PASSWORD` | Password chosen for the `.p12` |
   | `IOS_PLAYER_PROFILE_BASE64` | Base64 of the Player distribution profile |
   | `IOS_OWNER_PROFILE_BASE64` | Base64 of the Owner distribution profile |
   | `ASC_KEY_ID` | App Store Connect API key ID |
   | `ASC_ISSUER_ID` | App Store Connect API issuer ID |
   | `ASC_PRIVATE_KEY_BASE64` | Base64 of the downloaded `.p8` |

   On Windows, copy a file's base64 value directly to the clipboard:

   ```powershell
   [Convert]::ToBase64String([IO.File]::ReadAllBytes('C:\secure\distribution.p12')) | Set-Clipboard
   ```

   Repeat for the two profiles and `.p8`. Paste only into the corresponding
   GitHub secret. No Apple password, private key or signing file belongs in Git.

## Upload and invite friends

1. Run **iOS Build and TestFlight** manually with **upload_testflight** checked.
   Both apps build and upload. Choose a publicly reachable **HTTPS** staging API
   to keep test bookings/payments separate, or deliberately use the production
   default `https://www.kocourt.com/api`. This setting does not switch the
   backend's Cashfree environment; configure sandbox payments on staging too.
2. Wait for Apple's processing, then complete any export compliance questions
   in App Store Connect. The app does not predeclare an encryption exemption.
3. For each app, create an external TestFlight group, complete beta review
   information (including a usable reviewer login/OTP arrangement), attach the
   build and submit for beta review. After approval, enable its public invitation
   link and share it with friends. They install Apple's TestFlight app first.
   Uploading alone does not create or approve an external invitation link.
4. Test OTP login, photo uploads, location on Player, bookings, Cashfree sandbox
   payment success/cancellation, and returning from UPI/WhatsApp on a real iPhone.

Build numbers use `workflow run number.run attempt`, making a workflow re-run
uploadable. If uploading outside this workflow, keep build numbers increasing.
Update each app's `version:` in `pubspec.yaml` when changing its release version.
The workflow retains signed IPA artifacts for seven days. Those files still
require Apple's supported distribution; the TestFlight link is what friends use.

## Local maintenance

The generated Xcode projects, Podfiles and app icons are committed. CocoaPods
installs on the Mac runner during the build; Windows does not compile Xcode code.
To regenerate only the iOS icons, run in each app folder:

```powershell
flutter pub run flutter_launcher_icons -f ios-icons.yaml
```

Photo-library and camera usage descriptions are configured for both apps. Only
Player requests location, with the geolocator Always permission bypass enabled.
Cashfree/WhatsApp query schemes follow Cashfree's Flutter integration guide:
https://www.cashfree.com/docs/payments/online/mobile/flutter

The first macOS workflow run is required to verify native compilation and plugin
compatibility; Windows-only validation cannot establish that. No upload has
occurred as part of preparing these files.
