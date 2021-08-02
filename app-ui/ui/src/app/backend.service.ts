import { HttpClient, HttpParams } from '@angular/common/http';
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
  public static HOSPITAL = '+';
  public static HOUSE = 'H';
  public static EMPTY = 'O';
  public static SUSCEPTIBLE = 'SUSCEPTIBLE';
  public static MILD = 'MILD';
  public static PRESYMPTOMATIC = 'PRESYMPTOMATIC';
  public static ASYMPTOMATIC = 'ASYMPTOMATIC';
  public static INFECTED = 'INFECTED';
  public static SEVERE = 'SEVERE';
  public static HOSPITALIZED = 'HOSPITALIZED';
  public static RECOVERED = 'RECOVERED';
  public static DECEASED = 'DECEASED';
  public static INFECTION_STATUS = [
    BackendService.SUSCEPTIBLE,
    BackendService.MILD,
    BackendService.PRESYMPTOMATIC,
    BackendService.ASYMPTOMATIC,
    BackendService.INFECTED,
    BackendService.SEVERE,
    BackendService.HOSPITALIZED,
    BackendService.RECOVERED,
    BackendService.DECEASED,
  ];

  constructor(private http: HttpClient) {}

  initModel(payload: any): Observable<any> {
    return this.http.post('http://localhost:8082/init', payload);
  }

  terminateModel(modelName: string): Observable<any> {
    let params = { model_name: modelName };
    return this.http.get('http://localhost:8082/terminate', { params: params });
  }

  step(modelName: string) {
    let params = { model_name: modelName };
    return this.http.get('http://localhost:8082/step', { params: params });
  }

  updateModel(modelName: string, payload: any) {
    let params = new HttpParams();
    params.append('model_name', modelName);
    return this.http.post('http://localhost:8082/update', payload, {
      params: params,
    });
  }

  worldMap(modelName: string) {
    let params = { model_name: modelName };
    return this.http.get('http://localhost:8082/map', { params: params });
  }

  reloadData(): Observable<any> {
    return this.http.get('http://localhost:8082/get');
  }

  getBoxColorFromLocationType(locTypeSymbol: string) {
    if (locTypeSymbol == BackendService.EMPTY) return BackendService.WHITE;
    else if (locTypeSymbol == BackendService.HOUSE) return '#FFCCBC';
    else if (locTypeSymbol == BackendService.HOSPITAL) return '#81C784';
    return '#000000';
  }

  getBoxBorderColorFromLocationType(locTypeSymbol: string) {
    if (locTypeSymbol == BackendService.EMPTY) return '#00000000';
    else return BackendService.BLACK;
  }

  getLocationType(locTypeSymbol: string) {
    if (locTypeSymbol == BackendService.HOUSE) return 'House';
    else if (locTypeSymbol == BackendService.HOSPITAL) return 'Hospital';
    return 'Road';
  }

  getColorFromInfectionStatus(inf: string) {
    if (inf == BackendService.SUSCEPTIBLE) return '#42A5F5';
    if (inf == BackendService.ASYMPTOMATIC) return '#BA68C8';
    if (
      inf == BackendService.MILD ||
      inf == BackendService.INFECTED ||
      inf == BackendService.SEVERE
    )
      return '#E53935';
    if (inf == BackendService.HOSPITALIZED) return '#00ff76';
    if (inf == BackendService.RECOVERED) return '#9E9E9E';
    if (inf == BackendService.DECEASED) return '#00000000';
    return '#000000';
  }
}
