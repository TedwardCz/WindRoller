Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.IO

# Add Windows API support for dark title bar
$code = @'
using System;
using System.Runtime.InteropServices;

public class DarkMode {
    [DllImport("dwmapi.dll")]
    private static extern int DwmSetWindowAttribute(IntPtr hwnd, int attr, ref int attrValue, int attrSize);

    private const int DWMWA_USE_IMMERSIVE_DARK_MODE = 20;

    public static bool UseDarkMode(IntPtr handle) {
        int darkMode = 1;
        return DwmSetWindowAttribute(handle, DWMWA_USE_IMMERSIVE_DARK_MODE, ref darkMode, sizeof(int)) == 0;
    }
}
'@

try {
    Add-Type -TypeDefinition $code -Language CSharp
} catch {
    Write-Host "Error loading Windows API support. Title bar customization may not work."
}

# Error handling for assembly loading
try {
    [System.Windows.Forms.Application]::EnableVisualStyles()
} catch {
    Write-Host "Error loading Windows Forms. Please ensure .NET Framework is installed."
    exit 1
}

# Function to get history file path
function Get-HistoryFilePath {
    $exePath = [System.IO.Path]::GetDirectoryName([System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName)
    return Join-Path $exePath "WindRoller_History.txt"
}

# Function to save roll to history
function Save-RollHistory {
    param(
        [string]$rollText,
        [int]$total,
        [string[]]$rollDetails
    )
    try {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $historyEntry = "[$timestamp] $rollText"
        $historyFile = Get-HistoryFilePath
        Add-Content -Path $historyFile -Value $historyEntry -ErrorAction Stop
    } catch {
        Write-Host "Could not save to history: $_"
    }
}

# Add required Windows API calls
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

public class ScrollAPI {
    [DllImport("user32.dll")]
    public static extern int SendMessage(IntPtr hWnd, int wMsg, IntPtr wParam, IntPtr lParam);
    
    [DllImport("user32.dll")]
    public static extern int GetWindowLong(IntPtr hWnd, int nIndex);
    
    [DllImport("user32.dll")]
    public static extern int SetWindowLong(IntPtr hWnd, int nIndex, int dwNewLong);
    
    public const int EM_LINESCROLL = 0x00B6;
    public const int EM_GETSCROLLPOS = 0x4DD;
    public const int EM_SETSCROLLPOS = 0x4DE;
    public const int WM_VSCROLL = 0x115;
    public const int WM_HSCROLL = 0x114;
    public const int SB_TOP = 6;
    public const int GWL_STYLE = -16;
    public const int WS_VSCROLL = 0x00200000;
    public const int SIF_RANGE = 0x0001;
    public const int SIF_PAGE = 0x0002;
    public const int SIF_POS = 0x0004;
    public const int SIF_TRACKPOS = 0x0010;
    public const int SIF_ALL = (SIF_RANGE | SIF_PAGE | SIF_POS | SIF_TRACKPOS);
}
"@

# Function to update result
function Update-Result {
    param($text, $total)
    # Get timestamp for history
    $timestamp = Get-Date -Format "HH:mm:ss"
    
    # Create the full line
    $fullLine = "[$timestamp] $text"
    
    # If line is too long, truncate with ellipses
    if ($fullLine.Length -gt 1000) {
        $fullLine = $fullLine.Substring(0, 997) + "..."
    }
    
    # Add new line only if there's existing text
    if ($global:resultBox.Text.Length -gt 0) {
        $global:resultBox.Text = $global:resultBox.Text.TrimEnd("`r`n") + "`r`n" + $fullLine
    } else {
        $global:resultBox.Text = $fullLine
    }
    
    # Move to the last line and ensure left alignment
    $global:resultBox.SelectionStart = $global:resultBox.TextLength
    $global:resultBox.ScrollToCaret()
    
    # Scroll horizontally to the start
    [ScrollAPI]::SendMessage($global:resultBox.Handle, [ScrollAPI]::EM_LINESCROLL, [IntPtr](-1000), [IntPtr]0)
    
    $global:totalBox.Text = $total
}

# Function to roll dice and format result
function Roll-Dice {
    param (
        [int]$sides,
        [int]$count
    )
    $rolls = @()
    $total = 0
    $rollDetails = @()
    
    if ($count -gt 0) {
        for ($i = 0; $i -lt $count; $i++) {
            $roll = Get-Random -Minimum 1 -Maximum ($sides + 1)
            $rolls += $roll
            $total += $roll
            $rollDetails += "$roll(d$sides)"
        }
        $rollText = "Rolling ${count}d${sides}: " + ($rolls -join ", ")
        Update-Result $rollText $total
    }
    return $total
}

# Create the main form
$form = New-Object System.Windows.Forms.Form
$form.Text = 'WindRoller'
$form.Size = New-Object System.Drawing.Size(350,700)  
$form.StartPosition = 'CenterScreen'
$form.BackColor = [System.Drawing.Color]::FromArgb(30, 30, 30)
$form.ForeColor = [System.Drawing.Color]::White
$form.FormBorderStyle = 'FixedSingle'
$form.MaximizeBox = $false

# Add handler for dark mode
$form.Add_HandleCreated({
    try {
        [void][DarkMode]::UseDarkMode($this.Handle)
    } catch {
        Write-Host "Could not apply dark mode. This feature requires Windows 10 or later."
    }
})

# Create tooltip for result box
$tooltip = New-Object System.Windows.Forms.ToolTip
$tooltip.ShowAlways = $true
$tooltip.InitialDelay = 100
$tooltip.AutoPopDelay = 5000
$tooltip.ReshowDelay = 100
$tooltip.BackColor = [System.Drawing.Color]::FromArgb(45, 45, 45)
$tooltip.ForeColor = [System.Drawing.Color]::White

# Create a panel for result box
$resultBoxPanel = New-Object System.Windows.Forms.Panel
$resultBoxPanel.Location = New-Object System.Drawing.Point(50,20)
$resultBoxPanel.Size = New-Object System.Drawing.Size(240,95)
$resultBoxPanel.BackColor = [System.Drawing.Color]::FromArgb(128, 128, 128)
$resultBoxPanel.Padding = New-Object System.Windows.Forms.Padding(2)

# Create a result textbox
$global:resultBox = New-Object System.Windows.Forms.TextBox
$global:resultBox.Dock = [System.Windows.Forms.DockStyle]::Fill
$global:resultBox.Multiline = $true
$global:resultBox.ScrollBars = 'Vertical'
$global:resultBox.WordWrap = $false
$global:resultBox.ReadOnly = $true
$global:resultBox.Font = New-Object System.Drawing.Font('Segoe UI', 6.5)
$global:resultBox.BackColor = [System.Drawing.Color]::FromArgb(45, 45, 45)
$global:resultBox.ForeColor = [System.Drawing.Color]::White
$global:resultBox.BorderStyle = [System.Windows.Forms.BorderStyle]::None

# Add result box to panel and panel to form
$resultBoxPanel.Controls.Add($global:resultBox)
$form.Controls.Add($resultBoxPanel)

# Load history file on form load
$form.Add_Shown({
    $historyPath = Get-HistoryFilePath
    if (Test-Path $historyPath) {
        # Read file line by line and truncate if needed
        $lines = Get-Content $historyPath
        $truncatedLines = $lines | ForEach-Object {
            if ($_.Length -gt 1000) {
                $_.Substring(0, 997) + "..."
            } else {
                $_
            }
        }
        $history = $truncatedLines -join "`r`n"
        if ($history) {
            $global:resultBox.Text = $history
            $global:resultBox.SelectionStart = $global:resultBox.Text.Length
            $global:resultBox.ScrollToCaret()
        }
    }
})

# Add handler to ensure left alignment whenever text changes
$global:resultBox.Add_TextChanged({
    [ScrollAPI]::SendMessage($this.Handle, [ScrollAPI]::EM_LINESCROLL, [IntPtr](-1000), [IntPtr]0)
})

# Add mouse handlers to prevent text selection and horizontal scroll
$global:resultBox.Add_MouseDown({
    param($sender, $e)
    $sender.SelectionLength = 0
    [ScrollAPI]::SendMessage($sender.Handle, [ScrollAPI]::EM_LINESCROLL, [IntPtr](-1000), [IntPtr]0)
})

$global:resultBox.Add_MouseUp({
    param($sender, $e)
    $sender.SelectionLength = 0
    [ScrollAPI]::SendMessage($sender.Handle, [ScrollAPI]::EM_LINESCROLL, [IntPtr](-1000), [IntPtr]0)
})

# Add handler to prevent horizontal scroll during mouse movement
$global:resultBox.Add_MouseMove({
    param($sender, $e)
    $sender.SelectionLength = 0
    [ScrollAPI]::SendMessage($sender.Handle, [ScrollAPI]::EM_LINESCROLL, [IntPtr](-1000), [IntPtr]0)
    
    # Show tooltip
    $charIndex = $sender.GetCharIndexFromPosition($e.Location)
    if ($charIndex -ge 0) {
        $lineIndex = $sender.GetLineFromCharIndex($charIndex)
        $lineStart = $sender.GetFirstCharIndexFromLine($lineIndex)
        $lineLength = if ($lineIndex -lt $sender.Lines.Count) { $sender.Lines[$lineIndex].Length } else { 0 }
        $line = $sender.Text.Substring($lineStart, $lineLength)
        if ($line -ne $tooltip.GetToolTip($sender)) {
            $tooltip.SetToolTip($sender, $line)
        }
    }
})

# Set HideSelection to false so the text doesn't look selected
$global:resultBox.HideSelection = $false

# Set small scroll bars
$style = [ScrollAPI]::GetWindowLong($global:resultBox.Handle, [ScrollAPI]::GWL_STYLE)
$style = $style -bor [ScrollAPI]::WS_VSCROLL
[void][ScrollAPI]::SetWindowLong($global:resultBox.Handle, [ScrollAPI]::GWL_STYLE, $style)

# Function to style a primary button (roll buttons)
function Set-PrimaryButtonStyle {
    param($button)
    $button.BackColor = [System.Drawing.Color]::FromArgb(171, 39, 39)  # Red color
    $button.ForeColor = [System.Drawing.Color]::White
    $button.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $button.Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Regular)
}

# Function to style a secondary button (Set to 1)
function Set-SecondaryButtonStyle {
    param($button)
    $button.BackColor = [System.Drawing.Color]::FromArgb(35, 35, 35)
    $button.ForeColor = [System.Drawing.Color]::Gray
    $button.FlatStyle = [System.Windows.Forms.FlatStyle]::Flat
    $button.Font = New-Object System.Drawing.Font('Segoe UI', 8, [System.Drawing.FontStyle]::Regular)
}

# Create buttons with their click events
$diceTypes = @(4, 6, 8, 10, 12, 20, 100)
$buttons = @()
$numericInputs = @{}
$y = 135  # Start position for first row (20px spacing from top output box which ends at 115)

foreach ($sides in $diceTypes) {
    # Create roll button
    $button = New-Object System.Windows.Forms.Button
    $button.Location = New-Object System.Drawing.Point(50,$y)
    $button.Size = New-Object System.Drawing.Size(75,30)
    $button.Text = "1d$sides"  # Changed to match initial value of 1
    Set-PrimaryButtonStyle $button
    
    # Create numeric input
    $numericInput = New-Object System.Windows.Forms.NumericUpDown
    $numericInput.Location = New-Object System.Drawing.Point(140,$y)  # Adjusted x position
    $numericInput.Size = New-Object System.Drawing.Size(65,30)  # Increased width from 50 to 65
    $numericInput.Height = 30
    $numericInput.Font = New-Object System.Drawing.Font('Segoe UI', 12)
    $numericInput.Minimum = 0
    $numericInput.Maximum = 1000
    $numericInput.Value = 1
    $numericInput.Increment = 1
    $numericInput.BackColor = [System.Drawing.Color]::FromArgb(45, 45, 45)
    $numericInput.ForeColor = [System.Drawing.Color]::White
    
    # Add custom mouse wheel handler
    $numericInput.Add_MouseWheel({
        param($sender, $e)
        # Suppress default behavior
        if ($e -is [System.Windows.Forms.HandledMouseEventArgs]) {
            $e.Handled = $true
        }
        
        # Calculate new value
        if ($e.Delta -gt 0) {
            if ($sender.Value -lt $sender.Maximum) {
                $sender.Value++
            }
        } else {
            if ($sender.Value -gt $sender.Minimum) {
                $sender.Value--
            }
        }
    }.GetNewClosure())

    # Store references for closure
    $currentButton = $button
    $currentSides = $sides

    # Add value changed handler to update button text
    $numericInput.Add_ValueChanged({
        $value = $this.Value
        $currentButton.Text = "${value}d$currentSides"
    }.GetNewClosure())

    $numericInputs[$sides] = $numericInput
    
    # Create Set to 1 button
    $set1Button = New-Object System.Windows.Forms.Button
    $set1Button.Location = New-Object System.Drawing.Point(220,$y)
    $set1Button.Size = New-Object System.Drawing.Size(70,30)
    $set1Button.Text = "Set to 1"
    Set-SecondaryButtonStyle $set1Button
    
    # Add click handlers
    $currentInput = $numericInput
    $button.Add_Click({
        $count = [int]$currentInput.Value
        if ($count -eq 0) {
            Update-Result "No dice to roll" 0
            $global:middleBox.Text = ""
            # Add zero roll to history
            $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            $historyEntry = "[$timestamp] 0"
            Add-Content -Path (Get-HistoryFilePath) -Value $historyEntry
            return
        }
        
        $rolls = @()
        $total = 0
        
        for ($i = 0; $i -lt $count; $i++) {
            $roll = Get-Random -Minimum 1 -Maximum ($currentSides + 1)
            $rolls += $roll
            $total += $roll
        }
        
        $resultText = "$total = " + ($rolls -join ",") + "(d$currentSides)"
        Update-Result $resultText $total
        $global:middleBox.Text = $rolls -join "+"
        
        # Add to history
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $historyEntry = "[$timestamp] $resultText"
        Add-Content -Path (Get-HistoryFilePath) -Value $historyEntry
    }.GetNewClosure())
    
    $set1Button.Add_Click({
        $currentInput.Value = 1
    }.GetNewClosure())
    
    $buttons += $button
    $buttons += $set1Button
    $y += 40  # Space between rows
}

# Calculate positions for bottom section
$bottomStartY = $y + 20  # Add some padding after the last die row

# Create Set All to 0 button
$setAllZeroButton = New-Object System.Windows.Forms.Button
$setAllZeroButton.Location = New-Object System.Drawing.Point(50,$bottomStartY)
$setAllZeroButton.Size = New-Object System.Drawing.Size(115,30)
$setAllZeroButton.Text = 'Set All to 0'
Set-SecondaryButtonStyle $setAllZeroButton
$setAllZeroButton.Add_Click({
    foreach ($input in $numericInputs.Values) {
        $input.Value = 0
    }
})
$form.Controls.Add($setAllZeroButton)

# Create View History button
$viewHistoryButton = New-Object System.Windows.Forms.Button
$viewHistoryButton.Location = New-Object System.Drawing.Point(175,$bottomStartY)
$viewHistoryButton.Size = New-Object System.Drawing.Size(115,30)
$viewHistoryButton.Text = 'View History'
Set-SecondaryButtonStyle $viewHistoryButton
$viewHistoryButton.Add_Click({
    $historyFile = Get-HistoryFilePath
    if (Test-Path $historyFile) {
        Start-Process notepad.exe -ArgumentList $historyFile
    } else {
        [System.Windows.Forms.MessageBox]::Show("No history found.", "WindRoller", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
    }
})
$form.Controls.Add($viewHistoryButton)

# Create Roll All button
$rollAllButton = New-Object System.Windows.Forms.Button
$rollAllButton.Location = New-Object System.Drawing.Point(50,($bottomStartY + 40))
$rollAllButton.Size = New-Object System.Drawing.Size(240,30)
$rollAllButton.Text = 'Roll All'
Set-PrimaryButtonStyle $rollAllButton
$rollAllButton.Font = New-Object System.Drawing.Font('Segoe UI', 12, [System.Drawing.FontStyle]::Bold)
$form.Controls.Add($rollAllButton)

$rollAllButton.Add_Click({
    $allResults = @()
    $grandTotal = 0
    $diceByType = @{}
    $allRolls = @()

    foreach ($sides in $diceTypes) {
        $count = [int]$numericInputs[$sides].Value
        if ($count -gt 0) {
            $rolls = @()
            for ($i = 0; $i -lt $count; $i++) {
                $roll = Get-Random -Minimum 1 -Maximum ($sides + 1)
                $rolls += $roll
                $grandTotal += $roll
            }
            $diceByType[$sides] = $rolls
            $allRolls += $rolls -join "+"
        }
    }
    
    if ($diceByType.Count -eq 0) {
        Update-Result "No dice to roll" 0
        $global:middleBox.Text = ""
        # Add zero roll to history
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $historyEntry = "[$timestamp] 0"
        Add-Content -Path (Get-HistoryFilePath) -Value $historyEntry
        return
    }
    
    $resultParts = @()
    foreach ($sides in $diceTypes) {
        if ($diceByType.ContainsKey($sides)) {
            $rolls = $diceByType[$sides]
            $resultParts += ($rolls -join ",") + "(d$sides)"
        }
    }
    
    $resultText = "$grandTotal = " + ($resultParts -join " + ")
    Update-Result $resultText $grandTotal
    $global:middleBox.Text = $allRolls -join "+"
    
    # Add to history
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $historyEntry = "[$timestamp] $resultText"
    Add-Content -Path (Get-HistoryFilePath) -Value $historyEntry
}.GetNewClosure())

# Create a panel for middle box
$middleBoxPanel = New-Object System.Windows.Forms.Panel
$middleBoxPanel.Location = New-Object System.Drawing.Point(50,($bottomStartY + 90))
$middleBoxPanel.Size = New-Object System.Drawing.Size(240,30)
$middleBoxPanel.BackColor = [System.Drawing.Color]::FromArgb(128, 128, 128)
$middleBoxPanel.Padding = New-Object System.Windows.Forms.Padding(2)

# Create middle box
$global:middleBox = New-Object System.Windows.Forms.TextBox
$global:middleBox.Dock = [System.Windows.Forms.DockStyle]::Fill
$global:middleBox.Font = New-Object System.Drawing.Font('Segoe UI', 14)
$global:middleBox.TextAlign = [System.Windows.Forms.HorizontalAlignment]::Center
$global:middleBox.ReadOnly = $true
$global:middleBox.BackColor = [System.Drawing.Color]::FromArgb(45, 45, 45)
$global:middleBox.ForeColor = [System.Drawing.Color]::White
$global:middleBox.BorderStyle = [System.Windows.Forms.BorderStyle]::None

# Add middle box to panel and panel to form
$middleBoxPanel.Controls.Add($global:middleBox)
$form.Controls.Add($middleBoxPanel)

# Create a panel for the border
$totalBoxPanel = New-Object System.Windows.Forms.Panel
$totalBoxPanel.Location = New-Object System.Drawing.Point(50,($bottomStartY + 130))
$totalBoxPanel.Size = New-Object System.Drawing.Size(240,50)
$totalBoxPanel.BackColor = [System.Drawing.Color]::Red
$totalBoxPanel.Padding = New-Object System.Windows.Forms.Padding(2)

# Create total box
$global:totalBox = New-Object System.Windows.Forms.TextBox
$global:totalBox.Dock = [System.Windows.Forms.DockStyle]::Fill
$global:totalBox.Font = New-Object System.Drawing.Font('Segoe UI', 22, [System.Drawing.FontStyle]::Bold)
$global:totalBox.TextAlign = [System.Windows.Forms.HorizontalAlignment]::Center
$global:totalBox.ReadOnly = $true
$global:totalBox.BackColor = [System.Drawing.Color]::FromArgb(45, 45, 45)
$global:totalBox.ForeColor = [System.Drawing.Color]::Red
$global:totalBox.Multiline = $true
$global:totalBox.AutoSize = $false
$global:totalBox.BorderStyle = [System.Windows.Forms.BorderStyle]::None

# Center text vertically by setting line height and padding
$lineHeight = [Math]::Ceiling($global:totalBox.Font.GetHeight())
$padding = [Math]::Max(0, ($totalBoxPanel.Height - $lineHeight) / 2)
$global:totalBox.Padding = New-Object System.Windows.Forms.Padding(0, $padding, 0, 0)

# Add textbox to panel and panel to form
$totalBoxPanel.Controls.Add($global:totalBox)
$form.Controls.Add($totalBoxPanel)

# Add all controls to form
try {
    foreach ($button in $buttons) {
        $form.Controls.Add($button)
    }
    foreach ($numInput in $numericInputs.Values) {
        $form.Controls.Add($numInput)
    }
} catch {
    Write-Host "Error adding controls to form: $_"
    exit 1
}

# Show the form
try {
    $form.Add_Shown({$form.Activate()})
    [System.Windows.Forms.Application]::Run($form)
} catch {
    Write-Host "Error displaying form: $_"
    exit 1
}
