Columns Game

A MIPS assembly implementation of the classic Columns puzzle game.  
Built with bitmap display rendering, keyboard controls, score tracking, difficulty settings, and several gameplay enhancements.

Demo Features

- Real-time falling 3-gem columns
- Left / right movement
- Rotation of gem order
- Fast drop
- Match detection:
  - horizontal
  - vertical
  - diagonal
- Gravity after clearing
- Score system
- Difficulty selection
- Pause / resume
- Next-column preview
- Landing-position preview
- Special blocks with bonus effects
- Game over screen with final score

Controls

| Key | Action |
|-----|--------|
| `a` | Move left |
| `d` | Move right |
| `s` | Move down faster |
| `w` | Rotate current column |
| `p` | Pause / resume |
| `q` | Quit game |

Gameplay

The player controls a vertical stack of three falling gems.  
The goal is to align **three matching gems** in a row to clear them from the board and gain points.

Matches can be formed in four directions:
- Horizontal
- Vertical
- Diagonal down-right
- Diagonal down-left

After a match is cleared, gems above fall down automatically, which may create chain reactions.

Difficulty Modes

At the start of the game, the player can choose a difficulty level:

- `1` — Easy
- `2` — Medium
- `3` — Hard

Different difficulty levels change the automatic falling speed.

Special Block

The game includes a special block type that appears with a small random chance.  
When cleared as part of a match, it removes the entire column it belongs to.

Display Setup

This project is designed for a MIPS simulator environment with:
- bitmap display
- keyboard memory-mapped input
- syscall support for timing and random generation

How to Run
1. Open the assembly file in your MIPS simulator
2. Enable bitmap display and keyboard MMIO tools
3. Assemble and run the program
4. Select difficulty
5. Play using the keyboard controls above

Authors

- Kaiwen Yang
- Yifei Yang
