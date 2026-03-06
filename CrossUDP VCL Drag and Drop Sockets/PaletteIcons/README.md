Palette icons for CrossUDP components

Files in this folder:
- `CrossUDPClient.svg` - Vector source for the client icon.
- `CrossUDPServer.svg` - Vector source for the server icon.
- `CrossUDPClient.bmp` - Delphi palette bitmap (generated).
- `CrossUDPServer.bmp` - Delphi palette bitmap (generated).
- `Generate-UDP-Icons.ps1` - Rebuilds the BMP icons using System.Drawing.

How the palette icons are wired:
1. `CrossUDPSockets.dproj` contains:
   - `RcItem Include="PaletteIcons\CrossUDPClient.bmp"` with `ResourceId=TCROSSUDPCLIENT`
   - `RcItem Include="PaletteIcons\CrossUDPServer.bmp"` with `ResourceId=TCROSSUDPSERVER`
   - `DCCReference Include="ComponentIcons.res"`

2. `CrossUDPSockets.dpk` includes:
   - `{$R 'CrossUDPSockets.res'}`
   - `{$R 'ComponentIcons.res'}`

3. `ComponentIcons.res` is built from `ComponentIcons.rc` and always carries palette icons.
4. You can build from either `.dpk` or `.dproj`; no extra `.dres` file is required for icons.
