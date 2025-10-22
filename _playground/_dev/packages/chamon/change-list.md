



For example, when first loads Changes is selected in Column1 and file change panel is shown

if down arrow is presseded it would highlight Baseline and change the view to the baseline panels, shown below

What ever column has focus should have a lighter border and lighter text to indicate it is the active column



if right arrow is pressed, active column becomes column two, and up and down arrows change the selection in column2

if right arrow is pressed again, active column is column3 and and up and down arrows change the selection in column3

If Enter is pressed the selected comm,and from column 2 is executed on the selection from colum 3

if left is hit, it changes focus back to colum 2

So if generate baseline is selected and right arrow is pressed it woudl do nothing
if activate is selected and right arrow is pressed it would have the focus be in column 3 to select which baseline to activate, and the enter key would execute activate on the selected baseline.






┌────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                                       ChaMon - File Change Monitor (Watching)                                                              │
└────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘
                ┌──────────────────────┐ ┌──────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
 [C]hanges      │ Generate Baseline    │ │   20251012-094324                                                                                                │
 [B]aseline     │ Activate Baseline    │ │ > 20251010-064525                                                                                                │
                │ Remove Baseline      │ │   20251007-082728                                                                                                │
                │                      │ │                                                                                                                  │
                │                      │ │                                                                                                                  │
                │                      │ │                                                                                                                  │
                │                      │ │                                                                                                                  │
                │                      │ │                                                                                                                  │
                │                      │ │                                                                                                                  │
                │                      │ │                                                                                                                  │                
                └──────────────────────┘ └──────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘ 
                                                                                                                   
 ↕ commands ←→ files [Q]uit [W]atch [H]elp [PgUp]/[PgDn]: Cycle between file views                                 
──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
 Open the selected file in default editor                                                                          









┌────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                                       ChaMon - File Change Monitor (Watching)                                                              │
└────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘
                ┌────────────┐ ┌─── Filtered ─ All ───────────────────────────────────────────────────────────────────────────────────── 20251012-094324 ───┐
 [C]hanges      │ View File  │ │ [20241016 14:28:02] NEW ✓ /boot/firmware/config.txt                                                                        │
 [B]aseline     │ Show Diff  │ │ [20241016 14:13:09] MOD ! /etc/hosts                                                                                       │
                │ Track      │ │                                                                                                                            │
                │ Untrack    │ │                                                                                                                            │
                │            │ │                                                                                                                            │
                │            │ │                                                                                                                            │
                │            │ │                                                                                                                            │
                │            │ │                                                                                                                            │
                └────────────┘ └────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘ 
                                                                                                                   
 ↕ commands ←→ files [Q]uit [W]atch [H]elp [PgUp]/[PgDn]: Cycle between file views                                 
──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────
 Open the selected file in default editor                                                                          
 
 
 
 










===============================================================================


1. The filled triangle arrow should only be visable when a command is selected, 
2. there should be no green color
3. Make the 
    - active panel a thick white border 
    - inactive panel a thin dark grey border
4. We need to wrap the base commands in a border too
5. the panel borders should have a width of +1 of the longest command display text characcter count
6. All the commands from all the panels should be in the config.yaml


========================================================================================================================


If this is the top corner of the file view panel
┌────────────────────────────────────────────────────────────────

then 

─ Tracked ─ Untracked ─ Filtered ─ All ─

should be layed on top +2 x of the file panel left wall x ... giving 


┌── Tracked ─ Untracked ─ Filtered ─ All───────────────────────────────────────────────────────────────



                                 ─ Tracked ─ Untracked ─ Filtered ─ All 
                ┌────────────┐ ┌────────────────────────────────────────────────────────────── 20251012-094324 ───┐
                                 Filtered       
                ─ Filtered ─ All ─



========================================================================================================================


move the toggles to the bottom border line as an overlay, like the tab title overlay


└──────────────────────────────────────────────

overlay +3 [ Toggle1 ][ Toggle2 ]

giving

└──[ Toggle1 ][ Toggle2 ]──────────────────────



when col3 is focused the toggle title is bold

when off 
    - red and bold when the col3 is focused  
    - darkred and not bold when the col3 is not focused  
    
when on
    - green and bold when the col3 is focused  
    - darkgreen and not bold when the col3 is not focused      
    
========================================================================================================================

We need to create a standalone "popup" that will show as a centered box something like

it will always have 

┏━━━━━━━━━━━━━━━━━━━━━━━━┓
┃                        ┃

and 

┃                        ┃
┗━━━━━━━━━━━━━━━━━━━━━━━━┛

the the line of text in between sureround by two pipes... so


┏━━━━━━━━━━━━━━━━━━━━━━━━┓
┃                        ┃
┃     Line 1 of text     ┃
┃                        ┃
┗━━━━━━━━━━━━━━━━━━━━━━━━┛

┏━━━━━━━━━━━━━━━━━━━━━━━━┓
┃                        ┃
┃     Line 1 of text     ┃
┃   Line of more text    ┃
┃                        ┃
┗━━━━━━━━━━━━━━━━━━━━━━━━┛


========================================================================================================================

When remove baseline is selected, pop up a confirmation box

========================================================================================================================

Lets say baselines col3 is focused after selecting activate, activate is active and selected... but col3 is focused
when I select an item in col 3 with the arrow keys, and hit the binding r for remove, the remove command should be highlighted and executed while the command is running, but then revert back to the manually selected item in col2



========================================================================================================================





The initial baseline entry needs to be part of the ordering sort... so chronologically is should be at the bottom as it is the first baseline created.








This is how the panels are now for 


│    │ │             │ │                                                                      │
│    │ │             │ │                                                                      │
│    │ │             │ │                                                                      │
│    │ │             │ │                                                                      │
└────┘ └─────────────┘ └──────────────────────────────────────────────────────────────────────┘
                                                                             baseline:12341-624               
help_line.text
────────────────────────────────────────────────────────────
command.desc




I would like to add a new help line display that is panel specific....




│    │ │             │ │                                                                      │
│    │ │             │ │                                                                      │
│    │ │             │ │                                                                      │
│    │ │             │ │                                                                      │
└────┘ └─────────────┘ └──────────────────────────────────────────────────────────────────────┘
                        {NEW DISPLAY}                                        baseline:12341-624               
help_line.text
────────────────────────────────────────────────────────────
command.desc







New display is: pre_text + " " + bindings joined by " " + post text



baseline_panel:
    help_line: #>
        pre_text: ""
        post_text: ""
        bindings:
            - name: "[O]verwrite Initial"
              command: baseline:remove
              key: "del"
        
            - name: "[Del]: Remove Baseline
              key: "del"
              command: baseline:remove


would look like 

[O]verwrite Initial [Del]: Remove Baseline


but if pre_text was "Available: "

it would be

Available: [O]verwrite Initial [Del]: Remove Baseline


the help_line bindings are only active when its associated panel has focus







The tab titles in the file view should only be bold white when that is the active view on, else non bold dark grey

wqhen col3 is focused the 


┌──┤ Tracked ├─Untracked─All───────────────────────

┌──Tracked─┤ Untracked ├─All───────────────────────

┌──Tracked─Untracked─┤ All ├───────────────────────




    
    
    