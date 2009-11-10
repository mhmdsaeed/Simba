{
	This file is part of the Mufasa Macro Library (MML)
	Copyright (c) 2009 by Raymond van Venetië and Merlijn Wajer

    MML is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    MML is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with MML.  If not, see <http://www.gnu.org/licenses/>.

	See the file COPYING, included in this distribution,
	for details about the copyright.

    Colour.inc for the Mufasa Macro Library
}

function GetColor(x,y : integer) : TColor;
begin;
  Result := CurrThread.Client.MWindow.GetColor(x,y);
end;

function findcolor(var x, y: integer; color, x1, y1, x2, y2: integer): boolean;
begin
  Result := CurrThread.Client.MFinder.FindColor(x, y, color, x1, y1, x2, y2);
end;

function findcolortolerance(var x, y: integer; color, x1, y1, x2, y2, tol: integer): boolean;
begin
  Result := CurrThread.Client.MFinder.FindColorTolerance(x, y, color, x1, y1, x2, y2, tol);
end;

function FindColors(var TPA: TPointArray; Color, x1, y1, x2, y2: Integer): Boolean;
begin
  Result := CurrThread.Client.MFinder.FindColors(TPA, color, x1, y1, x2, y2);
end;

procedure SetColorToleranceSpeed(cts: Integer);
begin
  CurrThread.Client.MFinder.SetToleranceSpeed(cts);
end;

function SimilarColors(Col1,Col2,Tol : integer) : boolean;
begin;
  Result := CurrThread.Client.MFinder.SimilarColors(Col1,Col2,Tol);
end;

function CountColorTolerance(Color, xs, ys, xe, ye, Tolerance: Integer): Integer;
begin;
  result := CurrThread.Client.MFinder.CountColorTolerance(color,xs,ys,xe,ye,tolerance);
end;

function FindColorsTolerance(var Points: TPointArray; Color, xs, ys, xe, ye, Tolerance: Integer): Boolean;
begin;
  result := CurrThread.Client.MFinder.FindColorsTolerance(points,color,xs,ys,xe,ye,tolerance);
end;

function FindColorSpiral(var x, y: Integer; color, xs, ys, xe, ye: Integer): Boolean;
begin;
  result := CurrThread.Client.MFinder.FindColorSpiral(x,y,color,xs,ys,xe,ye);
end;

function FindColorsSpiralTolerance(x, y: Integer; var Points: TPointArray; color, xs, ys, xe, ye: Integer; Tolerance: Integer) : boolean;
begin;
  result := CurrThread.Client.MFinder.FindColorsSpiralTolerance(x,y,Points,color,xs,ys,xe,ye,tolerance);
end;