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
  public hiddenStates: Set<string> = new Set();

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

  downloadModelData(
    modelName: string,
    startStep: string,
    endStep: string
  ): Observable<any> {
    let params = { model_name: modelName, start: startStep, end: endStep };
    return this.http.get('http://localhost:8082/data', { params: params });
  }

  getBoxColorFromLocationType(locTypeSymbol: string) {
    if (locTypeSymbol == BackendService.EMPTY) return '#000000';
    else if (locTypeSymbol == BackendService.HOUSE) return '#3A4BB1';
    //041DBB
    // FFCCBC
    else if (locTypeSymbol == BackendService.HOSPITAL) return '#74CB7C'; //445943
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
    return (
      this._getColorFromInfectionStatusHelper(inf) +
      (this.hiddenStates.has(inf) ? '00' : 'ff')
    );
  }

  getPointRadiusFromInfectionStatus(inf: string): number {
    if (inf == BackendService.SUSCEPTIBLE) return 2;
    if (inf == BackendService.ASYMPTOMATIC) return 3;
    if (inf == BackendService.MILD) return 4;
    if (inf == BackendService.INFECTED) return 5;
    if (inf == BackendService.SEVERE) return 5;
    if (inf == BackendService.HOSPITALIZED) return 2;
    if (inf == BackendService.RECOVERED) return 2;
    if (inf == BackendService.DECEASED) return 1;
    return 3;
  }

  getPointBorderColor(
    inf: string,
    masked: boolean,
    numVaccineShots: number
  ): string {
    let color;
    if (masked) {
      // color = '#00ff76';
      color = this._getColorFromInfectionStatusHelper(inf);
    } else {
      color = '#000000';
    }
    return color + (this.hiddenStates.has(inf) ? '00' : '33');
  }

  getPointBorderWidth(
    inf: string,
    masked: boolean,
    numVaccineShots: number
  ): number {
    if (inf == BackendService.DECEASED) {
      return 0;
    }
    if (masked) {
      return 6 + numVaccineShots * 3;
    }
    return 1;
  }

  private _getColorFromInfectionStatusHelper(inf: string) {
    if (inf == BackendService.SUSCEPTIBLE) return '#42A5F5';
    if (inf == BackendService.ASYMPTOMATIC) return '#f0ea4f';
    if (inf == BackendService.MILD) return '#BA68C8';
    if (inf == BackendService.INFECTED) return '#f51d6c';
    if (inf == BackendService.SEVERE) return '#E53935';
    if (inf == BackendService.HOSPITALIZED) return '#00ff76';
    if (inf == BackendService.RECOVERED) return '#8B4513';
    if (inf == BackendService.DECEASED) return '#000000';
    return '#000000';
  }
}
