declare-option -docstring "shell command run to build the project" \
    str dotnetcmd dotnet
declare-option -docstring "name of the client in which utilities display information" \
    str toolsclient
declare-option -hidden int dotnet_current_error_line
declare-option -hidden str dotnet_error_pattern %sh{
    printf '^(/[^(]+)' # 1: full pathname to file
    printf '\('
    printf '([0-9]+)'  # 2: line number
    printf ','
    printf '([0-9]+)'  # 3: column number
    printf '\):\h*'
    printf '(?:(error \w+)|(warning \w+))'
    printf ':(.*?)$'     # 6: message
}

define-command -override -params .. \
    -docstring %{
        dotnet [<arguments>]: dotnet utility wrapper
        All the optional arguments are forwarded to the dotnet utility
     } dotnet %{ evaluate-commands %sh{
     output=$(mktemp -d "${TMPDIR:-/tmp}"/kak-dotnet.XXXXXXXX)/fifo
     mkfifo ${output}
     ( eval "${kak_opt_dotnetcmd}" "$@" > ${output} 2>&1 & ) > /dev/null 2>&1 < /dev/null

     printf %s\\n "evaluate-commands -try-client '$kak_opt_toolsclient' %{
               edit! -fifo ${output} -scroll *dotnet*
               set-option buffer filetype dotnet
               set-option buffer dotnet_current_error_line 0
               hook -always -once buffer BufCloseFifo .* %{ nop %sh{ rm -r $(dirname ${output}) } }
           }"
}}

add-highlighter -override shared/dotnet group
add-highlighter -override shared/dotnet/ regex %opt{dotnet_error_pattern} 1:cyan 2:green 3:green 4:red 5:yellow
add-highlighter -override shared/dotnet/ line '%opt{dotnet_current_error_line}' default+b

hook -group dotnet-highlight global WinSetOption filetype=dotnet %{
    add-highlighter -override window/dotnet ref dotnet
    hook -once -always window WinSetOption filetype=.* %{ remove-highlighter window/dotnet }
}

hook global WinSetOption filetype=dotnet %{
    hook buffer -group dotnet-hooks NormalKey <ret> dotnet-jump
    hook -once -always window WinSetOption filetype=.* %{ remove-hooks buffer dotnet-hooks }
}

declare-option -docstring "name of the client in which all source code jumps will be executed" \
    str jumpclient

define-command -override -hidden dotnet-open-error -params 4 %{
    evaluate-commands -try-client %opt{jumpclient} %{
        edit -existing "%arg{1}" %arg{2} %arg{3}
        echo -markup "{Information}{\}%arg{4}"
        try %{ focus }
    }
}

define-command -override -hidden dotnet-jump %{
    evaluate-commands %{
        execute-keys <a-h><a-l> s %opt{dotnet_error_pattern} <ret>l
        set-option buffer dotnet_current_error_line %val{cursor_line}
        dotnet-open-error "%reg{1}" "%reg{2}" "%reg{3}" "%reg{6}"
    }
}

define-command -override dotnet-next-error -docstring 'Jump to the next dotnet error' %{
    evaluate-commands -try-client %opt{jumpclient} %{
        buffer '*dotnet*'
        execute-keys "%opt{dotnet_current_error_line}ggl" "/^(?:\w:)?[^:\n]+:\d+:(?:\d+:)?%opt{dotnet_error_pattern}<ret>"
        dotnet-jump
    }
    try %{ evaluate-commands -client %opt{toolsclient} %{ execute-keys %opt{dotnet_current_error_line}g } }
}

define-command -override dotnet-previous-error -docstring 'Jump to the previous dotnet error' %{
    evaluate-commands -try-client %opt{jumpclient} %{
        buffer '*dotnet*'
        execute-keys "%opt{dotnet_current_error_line}g" "<a-/>^(?:\w:)?[^:\n]+:\d+:(?:\d+:)?%opt{dotnet_error_pattern}<ret>"
        dotnet-jump
    }
    try %{ evaluate-commands -client %opt{toolsclient} %{ execute-keys %opt{dotnet_current_error_line}g } }
}

