#!/bin/bash
if [ $# -ne 1 ]; then
    echo "Please provide a path to a .pgm file"
    exit 1
fi
# Assigning the path of the pgn file to a variable and checking if it exist
PGN_FILE=$1
if [ ! -f "$PGN_FILE" ]; then
    echo "File does not exist: $PGN_FILE"
    exit 1
fi

# Converting the moves from PGN to UCI using the provided python function
moves=($(python3 parse_moves.py "$(cat "$PGN_FILE")"))


# Making sure that the conversion succeeded
if [ $? -ne 0 ] || [ -z "$moves" ]; then
    echo "Error: Failed to parse PGN moves."
    exit 1
fi


# Initaliztion of the board visually and logically
declare -A board
init_board() {
    # White side
    board[a1]='R'; board[b1]='N'; board[c1]='B'; board[d1]='Q'; board[e1]='K'; board[f1]='B'; board[g1]='N'; board[h1]='R'
    for file in a b c d e f g h; do
        board[${file}2]='P'
    done
    # Black side
    board[a8]='r'; board[b8]='n'; board[c8]='b'; board[d8]='q'; board[e8]='k'; board[f8]='b'; board[g8]='n'; board[h8]='r'
    for file in a b c d e f g h; do
        board[${file}7]='p'
    done
    # Empty squares
    for rank in 3 4 5 6; do
        for file in a b c d e f g h; do
            board[${file}${rank}]="."
        done
    done
}


# Fucntion for the printing of the board
print_board() {
    echo "  a b c d e f g h"
    for rank in 8 7 6 5 4 3 2 1; do
        line="$rank "
        for file in a b c d e f g h; do
            line+="${board[${file}${rank}]} "
        done
        echo "$line$rank"
    done
    echo "  a b c d e f g h"
}

# This array will store the pieces that have been used in previous moves
declare -a move_history


# This function will apply the moves and save the pieces which took place in the history for later restoration
apply_move() {
    local move=$1
    # Movement's locartion's indices
    local from=${move:0:2}
    local to=${move:2:2}
    # Names of the pieces which participate
    local piece=${board[$from]}
    local captured=${board[$to]}
    # Save the move history
    move_history+=("$from$to$captured")
    # Dealing with coronation:
    # promote white pawn to queen
    if [[ "$piece" == "P" && "${to:1:1}" == "8" ]]; then
        board[$to]='Q'
    # promote black pawn to queen
    elif [[ "$piece" == "p" && "${to:1:1}" == "1" ]]; then
        board[$to]='q'
    fi
    # Dealing with castling:
    # White short castle
    if [[ "$piece" == "K" && "$from" == "e1" && "$to" == "g1" ]]; then
        board[f1]='R'; board[h1]='.'
    # White long castle
    elif [[ "$piece" == "K" && "$from" == "e1" && "$to" == "c1" ]]; then
        board[d1]='R'; board[a1]='.'
    # Black short castle
    elif [[ "$piece" == "k" && "$from" == "e8" && "$to" == "g8" ]]; then
        board[f8]='r'; board[h8]='.'
    # Black long castle
    elif [[ "$piece" == "k" && "$from" == "e8" && "$to" == "c8" ]]; then
        board[d8]='r'; board[a8]='.'
    fi
    # Regular case
        board[$to]=$piece
        board[$from]="."

}


# This function will undo moves by restoring the missing pieces from the history
undo_move() {
    # Get the last move from history
    local last_index=$((${#move_history[@]} - 1))
    local record=${move_history[$last_index]}
    # Getting the most recent move from the history
    move_history=("${move_history[@]:0:$last_index}")
    # Extract the right pieces from the history
    local from=${record:0:2}
    local to=${record:2:2}
    local captured=${record:4:1}
    # Placing back the extracted pieces
    local piece=${board[$to]}
    board[$from]=$piece
    board[$to]=$captured
}


# A function for printing the current move index and the board itself
print_current() {
    echo "Move $current_move/$total_moves"
    print_board

}

# Initialization for the game
current_move=0
total_moves=${#moves[@]}
init_board


# Displaying the metadata of the game using grep command
echo "Metadata from PGN file:"
grep '^\[' "$PGN_FILE"
echo ""
print_current


# The game loop
while true; do
    echo "Press 'd' to move forward, 'a' to move back, 'w' to go to the start, 's' to go to the end, 'q' to quit:"
    read key
    case $key in
        d)
            if (( current_move < total_moves )); then
                apply_move "${moves[$current_move]}"
                ((current_move++))
                print_current
            else
                echo "No more moves available."
            fi
            ;;
        a)
            if (( current_move > 0 )); then
                ((current_move--))
                undo_move "${moves[$current_move]}"
            fi
            print_current
            ;;
        w)
            current_move=0
            init_board
            print_current
            ;;
        s)
            init_board
            for ((i=0; i<total_moves; i++)); do
                apply_move "${moves[$i]}"
            done
            current_move=$total_moves
            print_current
            ;;
        q)
            echo "Exiting."
            echo "End of game."
            exit 0
            ;;
        *)
            if [[ -n "$key" ]]; then
                echo "Invalid key pressed: $key"
            fi
            ;;
    esac
done
