import { HttpClient } from '@angular/common/http';
import { Injectable } from '@angular/core';
import { Observable } from 'rxjs';

@Injectable({
  providedIn: 'root',
})
export class BackendService {
  public static GRAY = '#80808044';
  public static BLUE = '#0000ff22';
  public static WHITE = '#ffffff44';
  public static BLACK = '#000000ff';
  public static LOC_TYPE_ROAD = 'o';
  public static LOC_TYPE_HOUSE = 'h';
  public static LOC_TYPE_HOSPITAL = '+';

  constructor(private http: HttpClient) {}

  reloadData(url?: string): Observable<any> {
    if (url) return this.http.get(url);
    else return this.http.get('http://localhost:8082/get');
  }

  getBoxColorFromLocationType(locType: string) {
    if (locType == BackendService.LOC_TYPE_ROAD) return BackendService.WHITE;
    else if (locType == BackendService.LOC_TYPE_HOUSE) return '#FFCCBC';
    else if (locType == BackendService.LOC_TYPE_HOSPITAL) return '#81C784';
    return '#000000';
  }

  getBoxBorderColorFromLocationType(locType: string) {
    if (locType == BackendService.LOC_TYPE_ROAD) return '#00000000';
    else return BackendService.BLACK;
  }

  getColorFromInfectionStatus(inf: string) {
    if (inf == 'S') return '#42A5F5';
    if (inf == 'IU') return '#4A148C';
    if (inf == 'ID') return '#E53935';
    if (inf == 'R') return '#9E9E9E';
    return '#000000';
  }
}
