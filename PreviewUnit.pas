unit PreviewUnit;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, ExtCtrls, StdCtrls;

type
  TPreviewForm = class(TForm)
    PreviewImage: TImage;
    procedure FormShow(Sender: TObject);
  private
    { Private declarations }
  public
    procedure Reposition;
  end;

var
  PreviewForm: TPreviewForm;

implementation

uses MainUnit;

{$R *.dfm}

procedure TPreviewForm.Reposition;
var
  menuRect: TRect;
begin
  with MainForm.URLMenu do
    GetMenuItemRect(0, Handle, linksCount - 1, menuRect);

  if (menuRect.Left > GetSystemMetrics(SM_CXSCREEN) - menuRect.Right) then
    Self.Left := menuRect.Left - Self.Width - 10
  else
    Self.Left := menuRect.Right + 10;

  if (menuRect.Top > GetSystemMetrics(SM_CYSCREEN) - menuRect.Bottom) then
    Self.Top := menuRect.Bottom - Self.Height
  else begin
    with MainForm.URLMenu do
      GetMenuItemRect(0, Handle, 0, menuRect);
    Self.Top := menuRect.Top;
  end;
end;

procedure TPreviewForm.FormShow(Sender: TObject);
begin
  Left := -500;
  Top := -500;
end;

end.
