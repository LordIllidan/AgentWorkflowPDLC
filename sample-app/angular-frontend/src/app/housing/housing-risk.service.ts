import { Injectable, inject } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { Observable } from 'rxjs';
import { HousingEvaluationRequest, HousingEvaluationResponse } from './housing-risk.types';

@Injectable({ providedIn: 'root' })
export class HousingRiskService {
  private readonly http = inject(HttpClient);

  evaluate(req: HousingEvaluationRequest): Observable<HousingEvaluationResponse> {
    return this.http.post<HousingEvaluationResponse>(
      'http://localhost:8080/api/risk/housing/evaluate',
      req
    );
  }
}
