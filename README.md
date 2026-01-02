# mixassist

**mixassist** is a lightweight, keyboard-driven audio playback and navigation tool built for critical listening, mixing, and reference comparison. It emphasizes speed, musical navigation, and minimal UI so you can focus entirely on sound.

---

## Features

- **Unlimited Decks**
  - Load any number of audio files as independent decks.
- **Fast Deck Switching**
  - Instantly cycle between decks during playback.
- **Musical Navigation**
  - Move forward or backward by musical bars.
  - Jump directly to preset markers.
- **LUFS Normalization**
  - Toggle loudness normalization for accurate A/B comparisons.
- **Channel Isolation**
  - Solo left or right channels or return to stereo center.
- **Keyboard-First Design**
  - All major actions are performed via simple keystrokes.


## Usage

### Launching mixassist

Initialize mixassist by passing one or more audio files as arguments:

`mixassist a.wav  b.wav c.wav` 

Each file is loaded into its own **deck**.

----------

## Decks

-   There is **no limit** to the number of decks.
    
-   Each deck maintains its own playback position.
    
-   Decks can be switched instantly without stopping playback.
    
----------

## Example Workflow

1.  Load a mix and multiple reference tracks:
    
    `mixassist mix.wav ref1.wav ref2.wav` 
    
2.  Use `d` to cycle between decks.
    
3.  Toggle LUFS normalization (`n`) to remove loudness bias.
    
4.  Jump between song sections with `1–9`.
    
5.  Move bar-by-bar (`w` / `b`) to analyze transitions.
    
6.  Solo left or right channels to evaluate stereo decisions.
    

----------

## Keybinding Summary

### Key - Action

d - Switch deck

w - Forward 1 bar

b - Backward 1 bar

0 - Reset position

1–9 - Jump to marker

n - Toggle LUFS normalization

l - Solo left channel

r - Solo right channel

c - Center (stereo)
    

## About

**mixassist** is designed for engineers, producers, and musicians who want instant, unbiased audio comparison and precise musical navigation without breaking focus.
