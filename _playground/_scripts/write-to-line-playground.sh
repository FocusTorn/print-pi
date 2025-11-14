#!/bin/bash

echo "line1"
echo "line2"
echo "line3"

# --- Clearing Logic Starts Here ---

read -n 1 -s

# Move cursor UP 2 lines (from the line below line3 up to line2's line)
tput cuu 2

read -n 1 -s

# Erase from the current cursor position to the END OF THE SCREEN (ed = erase display)
# This clears line2, line3, and any subsequent blank lines
tput ed

read -n 1 -s

# The cursor is now sitting at the beginning of where "line2" used to be.

# Optional: To return the cursor to the bottom of the visible screen for the next prompt:
# Get max lines
MAX_LINES=$(tput lines)
# Move cursor to the last line (using 1-based indexing for tput cup)
tput cup $MAX_LINES 0



# #!/bin/bash

# # Clear the screen
# clear

# # Define the line number and text
# LINE_NUMBER=15
# TEXT="This text is on line $LINE_NUMBER."

# # Move the cursor to the specified line and column 1
# # \033[<LINE>;<COLUMN>H - Moves cursor to the specified line and column
# echo -e "\033[${LINE_NUMBER};1H${TEXT}"

# # Move the cursor to a new line after printing (optional)
# # This prevents subsequent output from overwriting the placed text
# echo -e "\033[$((${LINE_NUMBER} + 1));1H"

# # You can add more commands or text here, they will appear below the placed text
# echo "This is a subsequent line."