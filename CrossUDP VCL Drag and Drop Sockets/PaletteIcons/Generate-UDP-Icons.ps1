Add-Type -AssemblyName System.Drawing

function New-RoundedRectPath {
    param(
        [System.Drawing.RectangleF]$Rect,
        [float]$Radius
    )

    $path = New-Object System.Drawing.Drawing2D.GraphicsPath
    $d = $Radius * 2

    $path.AddArc($Rect.X, $Rect.Y, $d, $d, 180, 90)
    $path.AddArc($Rect.Right - $d, $Rect.Y, $d, $d, 270, 90)
    $path.AddArc($Rect.Right - $d, $Rect.Bottom - $d, $d, $d, 0, 90)
    $path.AddArc($Rect.X, $Rect.Bottom - $d, $d, $d, 90, 90)
    $path.CloseFigure()

    return $path
}

function New-ClientIcon {
    param([string]$Path)

    $bmp = New-Object System.Drawing.Bitmap 24, 24, ([System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    try {
        $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit

        $transparent = [System.Drawing.Color]::Fuchsia
        $g.Clear($transparent)

        $rect = New-Object System.Drawing.RectangleF 1.5, 1.5, 21, 21
        $brush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
            $rect,
            ([System.Drawing.Color]::FromArgb(24, 84, 196)),
            ([System.Drawing.Color]::FromArgb(0, 196, 255)),
            45
        )

        $g.FillEllipse($brush, $rect)
        $brush.Dispose()

        $borderPen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(245, 250, 255)), 1.4
        $g.DrawEllipse($borderPen, $rect)
        $borderPen.Dispose()

        $linePen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(236, 246, 255)), 1.8
        $linePen.StartCap = [System.Drawing.Drawing2D.LineCap]::Round
        $linePen.EndCap = [System.Drawing.Drawing2D.LineCap]::Round

        # Connected UDP-style mesh + directional send arrow for client
        $g.DrawLine($linePen, 7, 12, 12, 7)
        $g.DrawLine($linePen, 7, 12, 12, 17)
        $g.DrawLine($linePen, 12, 7, 14, 12)
        $g.DrawLine($linePen, 12, 17, 14, 12)
        $g.DrawLine($linePen, 14, 12, 18, 12)
        $linePen.Dispose()

        $arrow = New-Object System.Drawing.Point[] 3
        $arrow[0] = New-Object System.Drawing.Point 18, 9
        $arrow[1] = New-Object System.Drawing.Point 22, 12
        $arrow[2] = New-Object System.Drawing.Point 18, 15
        $g.FillPolygon((New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 228, 104))), $arrow)

        $nodeBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 255, 255))
        $g.FillEllipse($nodeBrush, 5.1, 10.1, 3.8, 3.8)
        $g.FillEllipse($nodeBrush, 10.1, 5.1, 3.8, 3.8)
        $g.FillEllipse($nodeBrush, 10.1, 15.1, 3.8, 3.8)
        $nodeBrush.Dispose()

        $tagBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(14, 36, 86))
        $font = New-Object System.Drawing.Font 'Segoe UI', 5.5, ([System.Drawing.FontStyle]::Bold), ([System.Drawing.GraphicsUnit]::Pixel)
        $fmt = New-Object System.Drawing.StringFormat
        $fmt.Alignment = [System.Drawing.StringAlignment]::Center
        $fmt.LineAlignment = [System.Drawing.StringAlignment]::Center
        $g.DrawString('U', $font, $tagBrush, (New-Object System.Drawing.RectangleF 13.0, 15.2, 7.5, 6.5), $fmt)

        $fmt.Dispose()
        $font.Dispose()
        $tagBrush.Dispose()

        $bmp.Save($Path, [System.Drawing.Imaging.ImageFormat]::Bmp)
    }
    finally {
        $g.Dispose()
        $bmp.Dispose()
    }
}

function New-ServerIcon {
    param([string]$Path)

    $bmp = New-Object System.Drawing.Bitmap 24, 24, ([System.Drawing.Imaging.PixelFormat]::Format24bppRgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    try {
        $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality

        $transparent = [System.Drawing.Color]::Fuchsia
        $g.Clear($transparent)

        $bodyRect = New-Object System.Drawing.RectangleF 2.2, 2.2, 19.6, 19.6
        $shapePath = New-RoundedRectPath -Rect $bodyRect -Radius 5.4

        $bodyBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush(
            $bodyRect,
            ([System.Drawing.Color]::FromArgb(2, 132, 76)),
            ([System.Drawing.Color]::FromArgb(104, 224, 137)),
            55
        )
        $g.FillPath($bodyBrush, $shapePath)
        $bodyBrush.Dispose()

        $borderPen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(242, 255, 246)), 1.3
        $g.DrawPath($borderPen, $shapePath)
        $borderPen.Dispose()
        $shapePath.Dispose()

        # Server rack face
        $rackBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(22, 68, 43))
        $g.FillRectangle($rackBrush, 5.4, 6.2, 13.2, 11.8)

        $slotPen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(124, 255, 174)), 1.2
        $g.DrawLine($slotPen, 6.5, 9.4, 17.5, 9.4)
        $g.DrawLine($slotPen, 6.5, 12.1, 17.5, 12.1)
        $g.DrawLine($slotPen, 6.5, 14.8, 17.5, 14.8)
        $slotPen.Dispose()

        $ledGreen = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(146, 255, 176))
        $ledBlue  = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(129, 232, 255))
        $g.FillEllipse($ledGreen, 15.6, 7.7, 1.9, 1.9)
        $g.FillEllipse($ledBlue, 15.6, 10.4, 1.9, 1.9)
        $g.FillEllipse($ledGreen, 15.6, 13.1, 1.9, 1.9)

        $ledGreen.Dispose()
        $ledBlue.Dispose()
        $rackBrush.Dispose()

        # Inbound packet chevrons
        $chevBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 241, 153))
        $leftChev = New-Object System.Drawing.Point[] 3
        $leftChev[0] = New-Object System.Drawing.Point 3, 4
        $leftChev[1] = New-Object System.Drawing.Point 7, 4
        $leftChev[2] = New-Object System.Drawing.Point 5, 7
        $g.FillPolygon($chevBrush, $leftChev)

        $rightChev = New-Object System.Drawing.Point[] 3
        $rightChev[0] = New-Object System.Drawing.Point 17, 4
        $rightChev[1] = New-Object System.Drawing.Point 21, 4
        $rightChev[2] = New-Object System.Drawing.Point 19, 7
        $g.FillPolygon($chevBrush, $rightChev)
        $chevBrush.Dispose()

        $bmp.Save($Path, [System.Drawing.Imaging.ImageFormat]::Bmp)
    }
    finally {
        $g.Dispose()
        $bmp.Dispose()
    }
}

$base = 'CrossUDP VCL Drag and Drop Sockets\\PaletteIcons'
New-ClientIcon -Path (Join-Path $base 'CrossUDPClient.bmp')
New-ServerIcon -Path (Join-Path $base 'CrossUDPServer.bmp')
