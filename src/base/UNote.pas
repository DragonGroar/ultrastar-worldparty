{*
    UltraStar WorldParty - Karaoke Game

	UltraStar WorldParty is the legal property of its developers,
	whose names	are too numerous to list here. Please refer to the
	COPYRIGHT file distributed with this source distribution.

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program. Check "LICENSE" file. If not, see
	<http://www.gnu.org/licenses/>.
 *}

unit UNote;

interface

{$IFDEF FPC}
  {$MODE Delphi}
{$ENDIF}

{$I switches.inc}

uses
  SysUtils,
  Classes,
  sdl2,
  dglOpenGL,
  UDisplay,
  UIni,
  ULog,
  ULyrics,
  UMusic,
  URecord,
  UScreenSingController,
  UScreenJukebox,
  USong,
  UTime;

type
  PPLayerNote = ^TPlayerNote;
  TPlayerNote = record
    Start:    integer;
    Length:   integer;
    Detect:   real;    // accurate place, detected in the note
    Tone:     real;
    Perfect:  boolean; // true if the note matches the original one, light the star
    Hit:      boolean; // true if the note hits the line
    NoteType: TNoteType;
  end;

  PPLayer = ^TPlayer;
  TPlayer = record
    Name:           UTF8String;

    // Index in Teaminfo record
    TeamID:         byte;
    PlayerID:       byte;

    // Scores
    Score:          real;
    ScoreLine:      real;
    ScoreGolden:    real;

    ScoreInt:       integer;
    ScoreLineInt:   integer;
    ScoreGoldenInt: integer;
    ScoreTotalInt:  integer;

    // LineBonus
    ScoreLast:      real;    // Last Line Score

    // PerfectLineTwinkle (effect)
    LastSentencePerfect: boolean;

    HighNote:       integer; // index of last note (= High(Note)?)
    LengthNote:     integer; // number of notes (= Length(Note)?).
    Note:           array of TPlayerNote;
  end;

  TStats = record
    Player: array of TPlayer;
    SongArtist:   String;
    SongTitle:    String;
  end;

  TMedleyPlaylist = record
    Song:               array of integer;
    NumMedleySongs:     integer;
    CurrentMedleySong:  integer;
    ApplausePlayed:     boolean;
    Stats:              array of TStats;
    NumPlayer:          integer;
  end;

{* Player and music info *}
var
  {**
   * Player info and state for each player.
   * The amount of players is given by PlayersPlay.
   *}
  Player: array of TPlayer;

  {**
   * Number of players or teams playing.
   * Possible values: 1 - 6
   *}
  PlayersPlay: integer;

  {**
   * Selected song for singing.
   *}
  CurrentSong: TSong;

  PlaylistMedley: TMedleyPlaylist;  // playlist medley

const
  MAX_SONG_SCORE = 10000;     // max. achievable points per song
  MAX_SONG_LINE_BONUS = 1000; // max. achievable line bonus per song

procedure Sing(Screen: TScreenSingController);
procedure NewSentence(CP: integer; Screen: TScreenSingController);
procedure NewBeatClick(Screen: TScreenSingController);  // executed when on then new beat for click
procedure NewBeatDetect(Screen: TScreenSingController); // executed when on then new beat for detection
procedure NewNote(CP: integer; Screen: TScreenSingController);       // detect note
function  GetMidBeat(Time: real): real;
function  GetTimeFromBeat(Beat: integer; SelfSong: TSong = nil): real;

procedure SingJukebox(Screen: TScreenJukebox);

implementation

uses
  Math,
  StrUtils,
  UCatCovers,
  UCommandLine,
  UCommon,
  UConfig,
  UDataBase,
  UGraphic,
  UGraphicClasses,
  UJoystick,
  ULanguage,
  UParty,
  UPathUtils,
  UPlatform,
  UPlaylist,
  USkins,
  USongs,
  UThemes;

function GetTimeForBeats(BPM, Beats: real): real;
begin
  Result := 60 / BPM * Beats;
end;

function GetBeats(BPM, msTime: real): real;
begin
  Result := BPM * msTime / 60;
end;

function GetMidBeat(Time: real): real;
begin
  Result := Time * CurrentSong.BPM / 60;
end;

function GetTimeFromBeat(Beat: integer; SelfSong: TSong = nil): real;
var
  Song: TSong;
begin

  if (SelfSong <> nil) then
    Song := SelfSong
  else
    Song := CurrentSong;

  Result := Song.GAP / 1000 + Beat * 60 / Song.BPM;
end;

procedure Sing(Screen: TScreenSingController);
var
  Count:   integer;
  CountGr: integer;
  CP:      integer;
  PetGr:   integer;
begin
  LyricsState.UpdateBeats();

  PetGr := 0;
  if (CurrentSong.isDuet) and (PlayersPlay <> 1) then
    PetGr := 1;

  // sentences routines
  for CountGr := 0 to PetGr do //High(CurrentSong.Lines)
  begin;
    CP := CountGr;

    // old parts
    LyricsState.OldLine := CurrentSong.Lines[CP].Current;

    // choose current parts
    for Count := 0 to CurrentSong.Lines[CP].High do
    begin
      if LyricsState.CurrentBeat >= CurrentSong.Lines[CP].Line[Count].Start then
        CurrentSong.Lines[CP].Current := Count;
    end;

    // clean player note if there is a new line
    // (optimization on halfbeat time)
    if CurrentSong.Lines[CP].Current <> LyricsState.OldLine then
      NewSentence(CP, Screen);

  end; // for CountGr

  // make some operations on clicks
  if {(LyricsState.CurrentBeatC >= 0) and }(LyricsState.OldBeatC <> LyricsState.CurrentBeatC) then
    NewBeatClick(Screen);

  // make some operations when detecting new voice pitch
  if (LyricsState.CurrentBeatD >= 0) and (LyricsState.OldBeatD <> LyricsState.CurrentBeatD) then
    NewBeatDetect(Screen);
end;

procedure SingJukebox(Screen: TScreenJukebox);
var
  Count:   integer;
  CountGr: integer;
  CP:      integer;
begin
  LyricsState.UpdateBeats();

  // sentences routines
  for CountGr := 0 to 0 do //High(CurrentSong.Lines)
  begin;
    CP := CountGr;
    // old parts
    LyricsState.OldLine := CurrentSong.Lines[CP].Current;

    // choose current parts
    for Count := 0 to CurrentSong.Lines[CP].High do
    begin
      if LyricsState.CurrentBeat >= CurrentSong.Lines[CP].Line[Count].Start then
        CurrentSong.Lines[CP].Current := Count;
    end;
  end; // for CountGr

  // on sentence change...
  Screen.onSentenceChange(CurrentSong.Lines[0].Current);
end;

procedure NewSentence(CP: integer; Screen: TScreenSingController);
var
  I: integer;
begin
  // clean note of player
  for I := 0 to High(Player) do
  begin
    if (not CurrentSong.isDuet) or (I mod 2 = CP) then
    begin
      Player[I].LengthNote := 0;
      Player[I].HighNote := -1;
      SetLength(Player[I].Note, 0);
    end;
  end;

  Screen.onSentenceChange(CP, CurrentSong.Lines[CP].Current)
end;

procedure NewBeatClick;
var
  Count: integer;
begin
  // beat click
  if not (CurrentSong.isDuet) or (PlayersPlay = 1) then
  begin
    if (Ini.BeatClick = 1) and ((LyricsState.CurrentBeatC + 4) mod 4 = 0) then //FIXME after remove resolution and notesgap use 4 as default...
      UMusic.AudioPlayback.PlaySound(UMusic.SoundLib.BeatClick);

    for Count := 0 to CurrentSong.Lines[0].Line[CurrentSong.Lines[0].Current].HighNote do
    begin
      //basisbit todo
      if (CurrentSong.Lines[0].Line[CurrentSong.Lines[0].Current].Note[Count].Start = LyricsState.CurrentBeatC) then
      begin
        // click assist
        if Ini.ClickAssist = 1 then
          UMusic.AudioPlayback.PlaySound(UMusic.SoundLib.BeatClick);

        // drum machine
        (*
        TempBeat := LyricsState.CurrentBeat; // + 2;
        if (TempBeat mod 8 = 0) then Music.PlayDrum;
        if (TempBeat mod 8 = 4) then Music.PlayClap;
        //if (TempBeat mod 4 = 2) then Music.PlayHihat;
        if (TempBeat mod 4 <> 0) then Music.PlayHihat;
        *)
      end;
    end;
  end;
end;

procedure NewBeatDetect(Screen: TScreenSingController);
  var
    MaxCP, CP, SentenceEnd: integer;
    I, J: cardinal;
begin
  // check for sentence end
  // we check all lines here because a new sentence may
  // have been started even before the old one finishes
  // due to corrupt lien breaks
  // checking only current line works to, but may lead to
  // weird ratings for the song files w/ the mentioned
  // errors
  // To-Do Philipp : check current and last line should
  // do it for most corrupt txt and for lines in
  // non-corrupt txts that start immediatly after the prev.
  // line ends
  MaxCP := 0;
  if (CurrentSong.isDuet) and (PlayersPlay <> 1) then
    MaxCP := 1;

  if (assigned(Screen)) then
  begin
    for J := 0 to MaxCP do
    begin
      CP := J;

      NewNote(CP, Screen);

      for I := 0 to CurrentSong.Lines[CP].High do
      begin
        with CurrentSong.Lines[CP].Line[I] do
        begin
          if (HighNote >= 0) then
          begin
            SentenceEnd := Note[HighNote].Start + Note[HighNote].Length;

            if (LyricsState.OldBeatD < SentenceEnd) and (LyricsState.CurrentBeatD >= SentenceEnd) then
              Screen.OnSentenceEnd(CP, I);
          end;
        end;
      end;
    end;
  end;
end;

procedure NewNote(CP: integer; Screen: TScreenSingController);
var
  LineFragmentIndex:   integer;
  CurrentLineFragment: PLineFragment;
  PlayerIndex:         integer;
  CurrentSound:        TCaptureBuffer;
  CurrentPlayer:       PPlayer;
  LastPlayerNote:      PPlayerNote;
  Line: 	       PLine;
  SentenceIndex:       integer;
  SentenceMin:         integer;
  SentenceMax:         integer;
  SentenceDetected:    integer; // sentence of detected note
  ActualBeat:          integer;
  ActualTone:          integer;
  NoteAvailable:       boolean;
  NewNote:             boolean;
  Range:               integer;
  NoteHit:             boolean;
  MaxSongPoints:       integer; // max. points for the song (without line bonus)
  CurNotePoints:       real;    // Points for the cur. Note (PointsperNote * ScoreFactor[CurNote])
  CurrentNoteType:     TNoteType;
begin
  ActualTone := 0;
  NoteHit := false;

  // TODO: add duet mode support
  // use CurrentSong.Lines[LineSetIndex] with LineSetIndex depending on the current player

  // count min and max sentence range for checking
  // (detection is delayed to the notes we see on the screen)
  SentenceMin := CurrentSong.Lines[CP].Current-1;
  if (SentenceMin < 0) then
    SentenceMin := 0;
  SentenceMax := CurrentSong.Lines[CP].Current;

  for ActualBeat := LyricsState.OldBeatD+1 to LyricsState.CurrentBeatD do
  begin
    // analyze player signals
    for PlayerIndex := 0 to PlayersPlay-1 do
    begin
      if (not CurrentSong.isDuet) or (PlayerIndex mod 2 = CP) then
      begin
        // check for an active note at the current time defined in the lyrics
        NoteAvailable := false;
        SentenceDetected := SentenceMin;
        for SentenceIndex := SentenceMin to SentenceMax do
        begin
          Line := @CurrentSong.Lines[CP].Line[SentenceIndex];
          for LineFragmentIndex := 0 to Line.HighNote do
          begin
            CurrentLineFragment := @Line.Note[LineFragmentIndex];
            // check if line is active
            if ((CurrentLineFragment.Start <= ActualBeat) and
              (CurrentLineFragment.Start + CurrentLineFragment.Length-1 >= ActualBeat)) and
              (CurrentLineFragment.NoteType <> ntFreestyle) and       // but ignore FreeStyle notes
              (CurrentLineFragment.Length > 0) then                   // and make sure the note length is at least 1
            begin
              SentenceDetected := SentenceIndex;
              NoteAvailable := true;
              Break;
            end;
          end;
          // TODO: break here, if NoteAvailable is true? We would then use the first instead
          // of the last note matching the current beat if notes overlap. But notes
          // should not overlap at all.
          //if (NoteAvailable) then
          //  Break;
        end;

        CurrentPlayer := @Player[PlayerIndex];
        CurrentSound := AudioInputProcessor.Sound[PlayerIndex];

        // at the beginning of the song there is no previous note
        if (Length(CurrentPlayer.Note) > 0) and (CurrentPlayer.HighNote > -1) then
          LastPlayerNote := @CurrentPlayer.Note[CurrentPlayer.HighNote]
        else
          LastPlayerNote := nil;

        // analyze buffer
        CurrentSound.AnalyzeBuffer;

        // add some noise
        // TODO: do we need this?
        //LyricsState.Tone := LyricsState.Tone + Round(Random(3)) - 1;

        // add note if possible
        if (CurrentSound.ToneValid and NoteAvailable) then
        begin
          CurrentNoteType := ntNormal;
          Line := @CurrentSong.Lines[CP].Line[SentenceDetected];
          // process until last note
          for LineFragmentIndex := 0 to Line.HighNote do
          begin
            CurrentLineFragment := @Line.Note[LineFragmentIndex];
            if (CurrentLineFragment.Start <= ActualBeat) and
              (CurrentLineFragment.Start + CurrentLineFragment.Length > ActualBeat) then
            begin
              // set the current note type
              CurrentNoteType := CurrentLineFragment.NoteType;
              // compare notes (from song-file and from player)

              // move players tone to proper octave
              while (CurrentSound.Tone - CurrentLineFragment.Tone > 6) do
                CurrentSound.Tone := CurrentSound.Tone - 12;

              while (CurrentSound.Tone - CurrentLineFragment.Tone < -6) do
                CurrentSound.Tone := CurrentSound.Tone + 12;

              // half size notes patch
              NoteHit := false;
              ActualTone := CurrentSound.Tone;
              if (ScreenSong.Mode = smNormal) then
                Range := 2 - Ini.PlayerLevel[PlayerIndex]
              else
                Range := 2 - Ini.Difficulty;

              // check if the player hit the correct tone within the tolerated range
              if
                (Abs(CurrentLineFragment.Tone - CurrentSound.Tone) <= Range)
                or (CurrentLineFragment.NoteType = ntRap)
                or (CurrentLineFragment.NoteType = ntRapGolden)
                or (UIni.Ini.PlayerLevel[PlayerIndex] = 3)
              then
              begin
                // adjust the players tone to the correct one
                // TODO: do we need to do this?
                // Philipp: I think we do, at least when we draw the notes.
                //          Otherwise the notehit thing would be shifted to the
                //          correct unhit note. I think this will look kind of strange.
                ActualTone := CurrentLineFragment.Tone;

                // half size notes patch
                NoteHit := true;

                if (Ini.LineBonus > 0) then
                  MaxSongPoints := MAX_SONG_SCORE - MAX_SONG_LINE_BONUS
                else
                  MaxSongPoints := MAX_SONG_SCORE;

                // Note: ScoreValue is the sum of all note values of the song
                // (MaxSongPoints / ScoreValue) is the points that a player
                // gets for a hit of one beat of a normal note
                // CurNotePoints is the amount of points that is meassured
                // for a hit of the note per full beat
                CurNotePoints := (MaxSongPoints / CurrentSong.Lines[CP].ScoreValue) * ScoreFactor[CurrentLineFragment.NoteType];

                case CurrentLineFragment.NoteType of
                  ntNormal:    CurrentPlayer.Score       := CurrentPlayer.Score       + CurNotePoints;
                  ntGolden:    CurrentPlayer.ScoreGolden := CurrentPlayer.ScoreGolden + CurNotePoints;
                  ntRap:       CurrentPlayer.Score       := CurrentPlayer.Score       + CurNotePoints;
                  ntRapGolden: CurrentPlayer.ScoreGolden := CurrentPlayer.ScoreGolden + CurNotePoints;
                end;

                // a problem if we use floor instead of round is that a score of
                // 10000 points is only possible if the last digit of the total points
                // for golden and normal notes is 0.
                // if we use round, the max score is 10000 for most songs
                // but a score of 10010 is possible if the last digit of the total
                // points for golden and normal notes is 5
                // the best solution is to use round for one of these scores
                // and round the other score in the opposite direction
                // so we assure that the highest possible score is 10000 in every case.
                CurrentPlayer.ScoreInt := round(CurrentPlayer.Score / 10) * 10;

                if (CurrentPlayer.ScoreInt < CurrentPlayer.Score) then
                  //normal score is floored so we have to ceil golden notes score
                  CurrentPlayer.ScoreGoldenInt := ceil(CurrentPlayer.ScoreGolden / 10) * 10
                else
                  //normal score is ceiled so we have to floor golden notes score
                  CurrentPlayer.ScoreGoldenInt := floor(CurrentPlayer.ScoreGolden / 10) * 10;


                CurrentPlayer.ScoreTotalInt := CurrentPlayer.ScoreInt +
                                               CurrentPlayer.ScoreGoldenInt +
                                               CurrentPlayer.ScoreLineInt;
              end;
            end; // operation
          end; // for

          // check if we have to add a new note or extend the note's length
          if (SentenceDetected = SentenceMax) then
          begin
            // we will add a new note
            NewNote := true;

            // if previous note (if any) was the same, extend previous note
            if ((CurrentPlayer.LengthNote > 0) and
                (LastPlayerNote <> nil) and
                (LastPlayerNote.Tone = ActualTone) and
                ((LastPlayerNote.Start + LastPlayerNote.Length) = ActualBeat)) then
            begin
              NewNote := false;
            end;

            // if is not as new note to control
            for LineFragmentIndex := 0 to Line.HighNote do
            begin
              if (Line.Note[LineFragmentIndex].Start = ActualBeat) then
                NewNote := true;
            end;

            // add new note
            if NewNote then
            begin
              // new note
              Inc(CurrentPlayer.LengthNote);
              Inc(CurrentPlayer.HighNote);
              SetLength(CurrentPlayer.Note, CurrentPlayer.LengthNote);

              // update player's last note
              LastPlayerNote := @CurrentPlayer.Note[CurrentPlayer.HighNote];
              with LastPlayerNote^ do
              begin
                Start    := ActualBeat;
                Length   := 1;
                Tone     := ActualTone; // Tone || ToneAbs
                //Detect := LyricsState.MidBeat; // Not used!
                Hit      := NoteHit; // half note patch
                NoteType := CurrentNoteType;
              end;
            end
            else
            begin
              // extend note length
              if (LastPlayerNote <> nil) then
                Inc(LastPlayerNote.Length);
            end;

            // check for perfect note and then light the star (on Draw)
            for LineFragmentIndex := 0 to Line.HighNote do
            begin
              CurrentLineFragment := @Line.Note[LineFragmentIndex];
              if (CurrentLineFragment.Start  = LastPlayerNote.Start) and
                (CurrentLineFragment.Length = LastPlayerNote.Length) and
                (CurrentLineFragment.Tone   = LastPlayerNote.Tone) then
              begin
                LastPlayerNote.Perfect := true;
              end;
            end;
          end; // if SentenceDetected = SentenceMax

        end; // if Detected
      end;
    end; // for PlayerIndex
  end; // for ActualBeat
  //Log.LogStatus('EndBeat', 'NewBeat');
end;

end.
