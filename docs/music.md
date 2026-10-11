# Music

The game plays background music from `game/assets3d/music/` (gitignored with the other assets; keep your own copy).
`game/src/ui/music.gd` picks the mood from the screen and the calendar, plays one track, leaves a quiet gap of
25–70 seconds, then plays another of the same mood (never the same one twice in a row). So you do not need hour-long
music: two to four tracks of 2–4 minutes per mood are plenty. N turns the music on or off in the game.

## Files

Name each file `<mood>_<anything>.mp3` (or `.ogg` / `.wav`) and drop it in `game/assets3d/music/`:

| mood | plays | how many |
|---|---|---|
| `theme` | the title screen, the pre-game screens and the intro flight (the narrator ducks it) | 1–2; the first one is the game's main theme |
| `spring` | March–May on the game's calendar | 2–3 |
| `summer` | June–August | 2–3 |
| `autumn` | September–November: the harvest and the first weeks in the cellar | 2–3 |
| `winter` | December–February: pruning, the wine resting in barrel | 2–3 |
| `tasting` | Tasting practice, the Wine Fair, the Cellar book | 1–2 |

## Suno prompts

Set **Instrumental** on (no vocals). If a track is short, use Extend. Generate a few and keep the best; the game is
calm, so prefer tracks without big drops or sudden endings. The prompts are style descriptions to paste into Suno's
style box.

- **theme_main**: cinematic orchestral, warm strings, solo cello melody, fingerpicked acoustic guitar, soft piano, slow build to a sweeping golden-hour swell, hopeful and nostalgic, European countryside, 70 bpm, instrumental
- **theme_title**: gentle acoustic guitar and piano, a simple warm melody, light strings, calm and inviting, a wine cellar by candlelight, 75 bpm, instrumental
- **spring_morning**: pastoral acoustic folk, nylon-string guitar, flute, light pizzicato strings, fresh and hopeful, early morning in the vineyard, 90 bpm, instrumental
- **spring_rain**: soft piano and acoustic guitar, a little melancholy, spring showers on a hillside, slow and spacious, 72 bpm, instrumental
- **summer_afternoon**: warm Mediterranean acoustic, mandolin and guitar, soft accordion, a lazy sunlit afternoon, relaxed, 80 bpm, instrumental
- **summer_evening**: mellow acoustic guitar duo, light strings, the long golden evening, warm and content, 76 bpm, instrumental
- **autumn_harvest**: rustic European folk, fiddle, accordion, upright bass, light percussion, a harvest day full of work, cheerful but mellow, 100 bpm, instrumental
- **autumn_cellar**: dark warm cello and piano, the smell of fermenting grapes in a stone cellar, slow and rich, 66 bpm, instrumental
- **winter_pruning**: sparse solo piano, soft cello, a quiet frosty morning among bare vines, reflective, 60 bpm, ambient, instrumental
- **winter_fire**: intimate acoustic guitar and soft strings, a fire in the hearth, cosy and calm, 70 bpm, instrumental
- **tasting_bar**: intimate jazz trio, brushed drums, upright bass, mellow piano, an evening wine bar, quiet, 85 bpm, instrumental

Suno's terms decide what you may do with the music (a paid plan grants ownership; the free plan is for
non-commercial use). This is a private project.
