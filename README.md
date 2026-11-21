# Debloat Windows installation media with the *Win Setup Prep Utility*
###### (codename: WIM-Debloat)

A pre-install focused script to modify your USB installer and optionally build a custom ISO in one fell swoop. Scans for compatible image formats like WIM, SWM, and ESD.

Select your Win edition to generate a summary of AppX packages included for that image with an easy checkbox list to make changes. Once finished, you can choose whether to write changes back to the drive or to save results into a raw WIM file for backup, or both. 

Stay field ready and never guess about Media Creation Tool updates again!

## Screenshots

<table>
  <tr>
    <td><img src="https://github.com/user-attachments/assets/387fbfcd-6b76-4db1-97ae-7e5d35b6ae50" alt="Screenshot 2026-11-18 041455" width="65%"></td>
    <td><img src="https://github.com/user-attachments/assets/8042f17b-e20b-47da-806c-4ba6ae905705" alt="Screenshot 2026-11-18 042403" width="100%"></td>
  </tr>
  <tr>
    <td><img src="https://github.com/user-attachments/assets/d7f71ec3-4ba4-4de0-af97-b05271b0980c" alt="Screenshot 2026-11-18 042624" width="100%"></td>
    <td><img src="https://github.com/user-attachments/assets/03ab1de9-bf3d-4b9a-8ea2-44357167f14c" alt="Screenshot 2026-11-18 043015" width="100%"></td>
  </tr>
</table>

## Get Started

1. Download and extract to a working directory of your choice.
2. Open an admin console, navigate to the src directory and run:

```PowerShell
Get-FileHash Purge-Bloat.ps1 # Verify against posted checksum
Set-ExecutionPolicy -RemoteSigned
Unblock-File Purge-Bloat.ps1
.\Purge-Bloat.ps1
```

## How It Works

There are 3 main phases: package provisioning, optimization, and configuration sets...

### 1. Package De-Provisioning Manager ✅

This is the checklist that summarizes what to purge and what to leave behind.

> Note: If you re-run on the same image, previously purged packages aren't listed but can be reprovisioned by mounting the standalone ISO from Media Creation Tool.

### 2. Optimize the Image Payload 🚢

- Package hard links
- Component base reset

> Re: Removals - Capabilities and optional features carry no benefit toward base install disk footprint past Win10.

### 3. The `$OEM$` Directory 🔧

Configuration sets to the root of the drive, consisting of:
- An answer file (Unattend.xml)
- Resources for importing a group policy (uses official MS tool "LGPO.exe")
- Anything else you want, just refer to MS Learn docs on adding a Distribution Share and paste to this folder. 🙂

## Some background and sources of inspiration on this project...

Ever wondered what Rufus does exactly? How does it come about giving you those great privacy options? What do the checkboxes mean under the hood? What's happening behind the scenes of all those OOBE changes? Are you the type of Win user not so comfortable with the idea of a 3rd party tool hacking through your system registry? Maybe you want to stick to official Microsoft tools to ensure all is good in the world on your computer and you didn't break anything. Then this might be the tool for you...

### Built for power users who have made the plunge into Pro Edition 🌊

#### Answer File Magic 🪄
You will find Unattend.xml under `$OEM$\$$`. This is largely verbatim what Rufus generates but with regedits removed and utilizing group policies instead...

#### Group Policy Management 🧰
You can import your own group policy by adding it to the distribution share under config/$OEM$/$1/Deploy/GPO

#### ADK Compatible ⚙️
Choose to backup the exported WIM if you need results in a format readable by Microsoft supported tools like Windows System Image Manager (SIM) etc. for validating. Allows you to explore the contents and generate new answer files. Edit the Unattend.xml with any Win SIM supported changes you'd like.

#### Rufus & ChrisTitus Inspired Preferences

1. "BypassNRO" to enforce local account creation
2. Make sure OneDrive doesn't reactivate
3. Privacy toggles under OOBE
4. Prevent BitLocker drive encryption

### Re: OneDrive (message from the dev)
In my experience at least so far, even though the executable seems to survive, neither this or CoPilot ever reinstalls itself. Don't hesitate to contribute in discussions if you notice anything. 👀

## System Requirements

Designed for Win11. (Might be backwards compatible with 10 but haven't tested.)

You shouldn't need to worry about updates to ADK or anything; Purge-Bloat will utilize the currently running system's copy of DISM. This should be adequate in most cases, especially if you are reinstalling the same version of Windows or to clean install on the same hardware.

If for some reason you need the shiny newest DISM for your mass deployment or multiple offline installs, then you probably are pre-release testing anyway and not reading this. 😉

### Detection Parameters

The match criteria is worth mentioning. Volumes labeled "ESD-USB" or "ESD-ISO" will be mounted. If you renamed your drives anything else, it won't find them so save that for after debloating. These are the Media Creation Tool default labels. (as of time this was written)

## Future Development

Expanded support for folks on Home Edition.

## Ways To Contribute

If you found this tool useful, consider starring the repo or supporting my projects via paypal to devops@adminstarbase.com.

[![Donate with PayPal](https://img.shields.io/badge/Donate-PayPal-00457C?logo=paypal&logoColor=white)](https://www.paypal.com/ncp/payment/8AKMASKU287UN)
