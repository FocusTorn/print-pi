# Define bracket characters globally
lb="["
rb="]"


# 86BBD8 33658A 2F4858


# Custom git status with stats first, branch last
function focused_git_status() {
  precmd_update_git_vars
  if [ -n "$__CURRENT_GIT_STATUS" ]; then
    STATUS="$ZSH_THEME_GIT_PROMPT_PREFIX"
    
    # File stats FIRST
    if [ "$GIT_STAGED" -ne "0" ]; then
      STATUS="$STATUS$ZSH_THEME_GIT_PROMPT_STAGED$GIT_STAGED%{${reset_color}%}"
    fi
    if [ "$GIT_CONFLICTS" -ne "0" ]; then
      STATUS="$STATUS$ZSH_THEME_GIT_PROMPT_CONFLICTS$GIT_CONFLICTS%{${reset_color}%}"
    fi
    if [ "$GIT_CHANGED" -ne "0" ]; then
      STATUS="$STATUS$ZSH_THEME_GIT_PROMPT_CHANGED$GIT_CHANGED%{${reset_color}%}"
    fi
    if [ "$GIT_DELETED" -ne "0" ]; then
      STATUS="$STATUS$ZSH_THEME_GIT_PROMPT_DELETED$GIT_DELETED%{${reset_color}%}"
    fi
    if [ "$GIT_UNTRACKED" -ne "0" ]; then
      STATUS="$STATUS$ZSH_THEME_GIT_PROMPT_UNTRACKED$GIT_UNTRACKED%{${reset_color}%}"
    fi
    if [ "$GIT_STASHED" -ne "0" ]; then
      STATUS="$STATUS$ZSH_THEME_GIT_PROMPT_STASHED$GIT_STASHED%{${reset_color}%}"
    fi
    if [ "$GIT_CLEAN" -eq "1" ]; then
      STATUS="$STATUS$ZSH_THEME_GIT_PROMPT_CLEAN"
    fi
    
    # Branch name LAST
    STATUS="$STATUS$ZSH_THEME_GIT_PROMPT_SEPARATOR"
    STATUS="$STATUS$ZSH_THEME_GIT_PROMPT_BRANCH$GIT_BRANCH%{${reset_color}%}"
    
    # Upstream info
    if [ "$GIT_BEHIND" -ne "0" ]; then
      STATUS="$STATUS$ZSH_THEME_GIT_PROMPT_BEHIND$GIT_BEHIND%{${reset_color}%}"
    fi
    if [ "$GIT_AHEAD" -ne "0" ]; then
      STATUS="$STATUS$ZSH_THEME_GIT_PROMPT_AHEAD$GIT_AHEAD%{${reset_color}%}"
    fi
    
    STATUS="$STATUS$ZSH_THEME_GIT_PROMPT_SUFFIX"
    echo "$STATUS"
  fi
}

# Custom function for directory display
function focused_dir() {
  local current_dir=$(pwd)
  
  if [[ $TERM = (*256color|*rxvt*) ]]; then
  turquoise="%{${(%):-"%F{81}"}%}"
  orange="%{${(%):-"%F{166}"}%}"
  purple="%{${(%):-"%F{135}"}%}"
  hotpink="%{${(%):-"%F{161}"}%}"
  limegreen="%{${(%):-"%F{118}"}%}"
else
  turquoise="%{${(%):-"%F{cyan}"}%}"
  orange="%{${(%):-"%F{yellow}"}%}"
  purple="%{${(%):-"%F{magenta}"}%}"
  hotpink="%{${(%):-"%F{red}"}%}"
  limegreen="%{${(%):-"%F{green}"}%}"
fi

  
  if [[ "$current_dir" == "/" ]]; then
    echo "%{$fg[yellow]%}${lb}ROOT: /${rb}%{$reset_color%}"
  else
    echo "%F{#86BBD8}${lb}%~${rb}%f"
  fi
}



# PROMPT=$'
# %{$fg_bold[blue]%}${lb}%D{%H:%M:%S}${rb}%{$reset_color%} $(git_super_status) $(focused_dir)\
# %F{#FF0000} %f%{$reset_color%}' # ➜

# PROMPT=$'
# %{$fg_bold[blue]%}${lb}%D{%H:%M:%S}${rb}%{$reset_color%} %{$reset_color%} $(focused_dir)\
# %F{#0277BD} %f%{$reset_color%}' # ➜ :

PROMPT=$'
%F{#33658A}${lb}%D{%H:%M:%S}${rb}%f $(focused_dir)\
%F{#0277BD} %f'


# "26547c","ef476f","ffd166","06d6a0","fffcf9"


RPROMPT='$(focused_git_status)'

ZSH_THEME_GIT_PROMPT_PREFIX="%F{#D500F9}"
ZSH_THEME_GIT_PROMPT_SEPARATOR=""
ZSH_THEME_GIT_PROMPT_SUFFIX="%F{#D500F9}"



ZSH_THEME_GIT_PROMPT_STAGED="%F{#06d6a0} %{%G%}" # 76FF03 F951FF
ZSH_THEME_GIT_PROMPT_CHANGED="%F{#ffd166} %{%G%}" # F93827 FF1212 
ZSH_THEME_GIT_PROMPT_DELETED="%F{#ef476f} %{✘%G%}"
ZSH_THEME_GIT_PROMPT_UNTRACKED="%F{#ABABAB} %{Ø%G%}"


ZSH_THEME_GIT_PROMPT_STASHED="%{$fg_bold[blue]%} %{󰴮%G%}%{$reset_color%}" # ⚑


ZSH_THEME_GIT_PROMPT_BRANCH="%F{#3574AC}%B %{%G%}%b"



# # ZSH_THEME_GIT_PROMPT_BEHIND="%{↓%G%}"
# # ZSH_THEME_GIT_PROMPT_AHEAD="%{↑%G%}"




# ZSH_THEME_GIT_PROMPT_CONFLICTS="%{$fg_bold[red]%} %{✖%G%}%{$reset_color%}"

# # ZSH_THEME_GIT_PROMPT_CHANGED="%F{#FFFF00}%b %{%G%}%f"



# ZSH_THEME_GIT_PROMPT_CLEAN="%{$fg_bold[green]%} %{✔%G%}%{$reset_color%}"

# Enable caching for better performance
# ZSH_THEME_GIT_PROMPT_CACHE=1

# # Show upstream branch info
# ZSH_THEME_GIT_SHOW_UPSTREAM=1
