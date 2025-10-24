# Define bracket characters globally
lb="["
rb="]"

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
    echo "%{$fg[cyan]%}${lb}%~${rb}%{$reset_color%}"
  fi
}


# I want time - git - prompt - venv 
# echo "Font test: AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz"

PROMPT=$'
%{$fg_bold[blue]%}${lb}%D{%H:%M:%S}${rb}%{$reset_color%} $(git_super_status) $(focused_dir)\
%{$fg[blue]%}->%{$fg_bold[blue]%} %#%{$reset_color%} '



# # date="%F{#505050}%B${lb}%D{%H:%M:%S}${rb}%b%f"

# PROMPT=$'
# %(date) $(git_super_status) $(focused_dir)\
# %{$fg[blue]%}->%{$fg_bold[blue]%} %#%{$reset_color%} '


ZSH_THEME_GIT_PROMPT_PREFIX="%F{#339171}${lb}%f"
ZSH_THEME_GIT_PROMPT_SEPARATOR=""
ZSH_THEME_GIT_PROMPT_SUFFIX="%F{#339171}${rb}%f"

ZSH_THEME_GIT_PROMPT_BRANCH="%F{#339171}"

ZSH_THEME_GIT_PROMPT_UNTRACKED="%F{#999999} %{…%G%}"
ZSH_THEME_GIT_PROMPT_STAGED="%F{#F951FF} %{↑%G%}" # ●🡅

ZSH_THEME_GIT_PROMPT_CONFLICTS="%{$fg_bold[red]%} %{✖%G%}"
ZSH_THEME_GIT_PROMPT_CHANGED="%{$fg_bold[yellow]%} %{+%G%}" #✚
ZSH_THEME_GIT_PROMPT_DELETED="%{$fg_bold[yellow]%} %{-%G%}"
# ZSH_THEME_GIT_PROMPT_BEHIND="%{↓%G%}"
# ZSH_THEME_GIT_PROMPT_AHEAD="%{↑%G%}"
ZSH_THEME_GIT_PROMPT_STASHED="%{$fg_bold[blue]%} %{⚑%G%}"
ZSH_THEME_GIT_PROMPT_CLEAN="%{$fg_bold[green]%} %{✔%G%}"

# Enable caching for better performance
# ZSH_THEME_GIT_PROMPT_CACHE=1

# # Show upstream branch info
# ZSH_THEME_GIT_SHOW_UPSTREAM=1
