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


unit UScreenOptionsAdvanced;

interface

{$MODE OBJFPC}

{$I switches.inc}

uses
  UCommon,
  sdl2,
  UMenu,
  UDisplay,
  UMusic,
  UFiles,
  UIni,
  UThemes;

type

  TScreenOptionsAdvanced = class(TMenu)
    public
      constructor Create; override;
      function ParseInput(PressedKey: cardinal; CharCode: UCS4Char; PressedDown: boolean): boolean; override;
      procedure OnShow; override;
  end;

implementation

uses
  UGraphic,
  UUnicodeUtils,
  SysUtils;

function TScreenOptionsAdvanced.ParseInput(PressedKey: cardinal; CharCode: UCS4Char; PressedDown: boolean): boolean;
begin
  Result := true;
  if (PressedDown) then
  begin // Key Down
    // check special keys
    case PressedKey of
      SDLK_ESCAPE,
      SDLK_BACKSPACE :
        begin
          UIni.Ini.Save;
          AudioPlayback.PlaySound(SoundLib.Back);
          FadeTo(@ScreenOptions);
        end;
      SDLK_RETURN:
        begin
          if Self.SelInteraction = 7 then
          begin
            UIni.Ini.Save;
            AudioPlayback.PlaySound(SoundLib.Back);
            FadeTo(@ScreenOptions);
          end;
        end;
      SDLK_DOWN:
        InteractNext;
      SDLK_UP :
        InteractPrev;
      SDLK_RIGHT:
        begin
          if (SelInteraction >= 0) and (SelInteraction <= 6) then
          begin
            AudioPlayback.PlaySound(SoundLib.Option);
            InteractInc;
          end;
        end;
      SDLK_LEFT:
        begin
          if (SelInteraction >= 0) and (SelInteraction <= 6) then
          begin
            AudioPlayback.PlaySound(SoundLib.Option);
            InteractDec;
          end;
        end;
    end;
  end;
end;

constructor TScreenOptionsAdvanced.Create;
begin
  inherited Create;

  LoadFromTheme(Theme.OptionsAdvanced);
  AddSelectSlide(Theme.OptionsAdvanced.SelectDebug, UIni.Ini.Debug, UIni.IDebug, 'OPTION_VALUE_');
  AddSelectSlide(Theme.OptionsAdvanced.SelectOscilloscope, UIni.Ini.Oscilloscope, UIni.IOscilloscope, 'OPTION_VALUE_');
  AddSelectSlide(Theme.OptionsAdvanced.SelectOnSongClick, UIni.Ini.OnSongClick, UIni.IOnSongClick, 'OPTION_VALUE_');
  AddSelectSlide(Theme.OptionsAdvanced.SelectAskBeforeExit, UIni.Ini.AskBeforeExit, UIni.IAskBeforeExit, 'OPTION_VALUE_');
  AddSelectSlide(Theme.OptionsAdvanced.SelectPartyPopup, UIni.Ini.PartyPopup, UIni.IPartyPopup, 'OPTION_VALUE_');
  AddSelectSlide(Theme.OptionsAdvanced.SelectTopScores, UIni.Ini.TopScores, UIni.ITopScores, 'OPTION_VALUE_');
  Self.AddSelectSlide(Theme.OptionsAdvanced.SelectSingTimebarMode, UIni.Ini.SingTimebarMode, UIni.ISingTimebarMode, 'OPTION_VALUE_');
  AddButton(Theme.OptionsAdvanced.ButtonExit);
  Self.AddText(UThemes.Theme.OptionsAdvanced.DebugDesc);
  Self.AddText(UThemes.Theme.OptionsAdvanced.OscilloscopeDesc);
  Self.AddText(UThemes.Theme.OptionsAdvanced.OnSongClickDesc);
  Self.AddText(UThemes.Theme.OptionsAdvanced.AskBeforeExitDesc);
  Self.AddText(UThemes.Theme.OptionsAdvanced.PartyPopupDesc);
  Self.AddText(UThemes.Theme.OptionsAdvanced.TopScoresDesc);
  Self.AddText(UThemes.Theme.OptionsAdvanced.SingTimebarModeDesc);

  Interaction := 0;
end;

procedure TScreenOptionsAdvanced.OnShow;
begin
  inherited;

  Interaction := 0;
end;

end.
