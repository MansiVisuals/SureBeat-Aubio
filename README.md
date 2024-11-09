SureBeat by Mansi Visuals


### Main development has moved away from aubio. Follow development at https://github.com/MansiVisuals/SureBeat


SureBeat is a Lua-based plugin for DaVinci Resolve, designed to help creators sync their videos to audio by detecting transients and adding markers directly on the audio clip. 

By leveraging Aubio for transient and tempo detection, and FFmpeg for audio conversion, SureBeat streamlines beat-syncing workflows for DaVinci Resolve users.

Features:
```
 •	Transient Detection: Automatically detects audio transients and marks them on your timeline.
 •	Tempo Detection: Analyzes audio tempo and places markers based on BPM.
 •	File Conversion: Supports various audio formats (e.g., .wav, .mp3, .flac, .aac, .ogg) through FFmpeg.
 •	Easy Integration: Seamlessly integrates with DaVinci Resolve.
```

Installation:

1. Download and Extract

Download the SureBeat package and ensure the folder structure remains as follows:

```
SureBeat/
├── SureBeat.lua                    # Main Script
├── Aubio/                          # Aubio binaries
│   ├── bin/
│   │   ├── aubioonset
│   │   └── aubiotempo              # macOS only for now
│   └── lib/
│       ├── libaubio.a
│       ├── libaubio.dylib
│       ├── other Aubio libraries   # See Windows files and macOS files
├── FFmpeg/                         # FFmpeg binaries
│   └── bin/
│       └── ffmpeg
├── LICENSE.txt                     # License file
└── README.md                       # README file
```

2. Place SureBeat in the DaVinci Resolve Scripts Directory

Move the entire SureBeat folder to the DaVinci Resolve Utility directory:

macOS:
```
/Library/Application Support/Blackmagic Design/DaVinci Resolve/Fusion/Scripts/Utility/
```

Windows:
```
C:\ProgramData\Blackmagic Design\DaVinci Resolve\Fusion\Scripts\Utility\
```


3. Run SureBeat in DaVinci Resolve
```
•	Open DaVinci Resolve.
•	Navigate to Workspace and locate SureBeat under Scripts.
•	Run the script and follow the on-screen instructions to analyze audio and add markers.
```

macOS Security Prompt for Unverified Binaries:

If macOS blocks unverified binaries (Aubio and FFmpeg), follow these steps to allow access:
```
•	Go to System Preferences > Security & Privacy > General.
•	Find the block message and click Allow Anyway for each blocked item.
•	Run SureBeat in DaVinci Resolve again, confirming each binary if prompted.
```

Console in DaVinci Resolve
```
• Open DaVinci Resolve.
•	Navigate to Workspace and select Console.
•	Use the Console to view task information and troubleshoot errors. Please include console output when reporting issues.
```

Support:

SureBeat is a personal project maintained in my free time. If you find it useful, consider supporting further development:
Donate on Ko-Fi:

https://ko-fi.com/surebeat#


License:

SureBeat by Mansi Visuals is proprietary software provided for free use (see LICENSE.txt for details).

Third-Party Licenses

SureBeat relies on the following open-source tools:

•	Aubio: Transient detection, licensed under GPLv3. See Aubio License:
  - https://aubio.org
  - https://github.com/aubio/aubio
  
•	FFmpeg: Audio support, licensed under LGPL/GPL. See FFmpeg License.
  - https://ffmpeg.org
  - https://github.com/FFmpeg/FFmpeg

These licenses apply solely to their respective binaries or executables.


Disclaimer:

SureBeat is provided “as-is” without any warranties. Mansi Visuals is not liable for any claims or damages arising from its use.
