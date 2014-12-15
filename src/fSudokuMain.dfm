object frmSudoku: TfrmSudoku
  Left = 388
  Top = 148
  BorderIcons = [biSystemMenu, biMinimize]
  BorderStyle = bsSingle
  Caption = 'frmSudoku'
  ClientHeight = 654
  ClientWidth = 720
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  Position = poDesktopCenter
  OnCreate = FormCreate
  OnDestroy = FormDestroy
  PixelsPerInch = 96
  TextHeight = 13
  object Panel1: TPanel
    Left = 0
    Top = 0
    Width = 720
    Height = 600
    Align = alTop
    BevelOuter = bvNone
    TabOrder = 0
    object imgTiles: TImage
      Left = 120
      Top = 0
      Width = 600
      Height = 600
      Align = alClient
      OnMouseDown = imgTilesMouseDown
      OnMouseMove = imgTilesMouseMove
    end
    object Panel2: TPanel
      Left = 0
      Top = 0
      Width = 120
      Height = 600
      Align = alLeft
      TabOrder = 0
    end
  end
  object Button1: TButton
    Left = 120
    Top = 616
    Width = 75
    Height = 25
    Caption = 'Button1'
    TabOrder = 1
    OnClick = Button1Click
  end
  object Button2: TButton
    Left = 312
    Top = 616
    Width = 75
    Height = 25
    Caption = 'Button2'
    TabOrder = 2
    OnClick = Button2Click
  end
end
