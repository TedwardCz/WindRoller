Be advised, EVERYTHING besides this singular line in this singular file was made by Winddsurf with absolutely no code written by a human.

# WindRoller

A beautiful PowerShell-based dice rolling application with a modern GUI interface.

## Features

- Roll multiple types of dice (d4, d6, d8, d10, d12, d20, d100)
- Set quantity for each die type (0-1000)
- Roll all dice at once
- View detailed roll results
- Track roll history
- Modern dark mode interface
- Keyboard shortcuts for quick dice rolling

## Usage

1. Run `WindRoller.exe`
2. Use the number inputs to set how many of each die type you want to roll
3. Click individual die buttons to roll specific dice
4. Click "Roll All" to roll all selected dice at once
5. View results in the output boxes
6. Use "View History" to see previous rolls
7. Use "Set All to 0" to quickly reset all dice counts

## Requirements

- Windows operating system
- PowerShell 5.1 or later

## Building

To rebuild the executable:
```powershell
Invoke-PS2EXE -InputFile WindRoller.ps1 -OutputFile WindRoller.exe -noConsole -title "WindRoller" -description "A beautiful dice rolling application" -company "WindRoller" -product "WindRoller" -copyright "WindRoller" -version "1.0.0.0"
