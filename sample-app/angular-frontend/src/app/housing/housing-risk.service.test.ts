import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import { TestBed } from '@angular/core/testing';
import { provideHttpClient } from '@angular/common/http';
import { provideHttpClientTesting, HttpTestingController } from '@angular/common/http/testing';
import { HousingRiskService } from './housing-risk.service';
import { HousingEvaluationRequest } from './housing-risk.types';

const API_URL = 'http://localhost:8080/api/risk/housing/evaluate';

const minimalRequest: HousingEvaluationRequest = {
  buildingAge: 0,
  floor: 0,
  totalFloors: 1,
  securityLevel: 'none',
  claimsLast5Years: 0,
  location: { floodZone: 'none', fireRiskZone: 'low', theftRiskZone: 'low', buildingDensity: 'rural' },
  specialFlags: { isVacant: false, isWoodenStructure: false, missingInspections: false, insuredSumPLN: 0 },
};

describe('HousingRiskService', () => {
  let service: HousingRiskService;
  let httpMock: HttpTestingController;

  beforeEach(() => {
    TestBed.configureTestingModule({
      providers: [provideHttpClient(), provideHttpClientTesting()],
    });
    service  = TestBed.inject(HousingRiskService);
    httpMock = TestBed.inject(HttpTestingController);
  });

  afterEach(() => httpMock.verify());

  it('sends POST to correct URL', () => {
    service.evaluate(minimalRequest).subscribe();
    const req = httpMock.expectOne(API_URL);
    expect(req.request.method).toBe('POST');
    req.flush({});
  });

  it('passes request body unchanged', () => {
    service.evaluate(minimalRequest).subscribe();
    const req = httpMock.expectOne(API_URL);
    expect(req.request.body).toEqual(minimalRequest);
    req.flush({});
  });
});
