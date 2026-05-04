import { describe, it, expect, beforeEach, afterEach } from 'vitest';
import { TestBed } from '@angular/core/testing';
import { provideHttpClient } from '@angular/common/http';
import { provideHttpClientTesting, HttpTestingController } from '@angular/common/http/testing';
import { HousingRiskComponent } from './housing-risk.component';

const API_URL = 'http://localhost:8080/api/risk/housing/evaluate';

const mockResponse = {
  algorithms: {
    pointBased: {
      score: 35,
      classification: 'medium',
      breakdown: { agePenalty: 20, floorFactor: 5, securityDiscount: 10, claimsPenalty: 20 },
    },
    weightBased: {
      score: 0.67,
      classification: 'high',
      breakdown: { flood: 0.18, fire: 0.02, theft: 0.35, density: 0.12 },
    },
    ruleBased: {
      classification: 'medium',
      triggeredRules: ['MISSING_INSPECTIONS'],
      blockedRules: ['VACANT_PROPERTY', 'WOODEN_STRUCTURE', 'HIGH_INSURED_SUM'],
    },
  },
  recommended: { classification: 'high', rationale: 'Rozbieżność algorytmów. Przyjęto najwyższy wynik: high.' },
};

describe('HousingRiskComponent', () => {
  let httpMock: HttpTestingController;

  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [HousingRiskComponent],
      providers: [provideHttpClient(), provideHttpClientTesting()],
    }).compileComponents();
    httpMock = TestBed.inject(HttpTestingController);
  });

  afterEach(() => httpMock.verify());

  it('C-01: renders without error', async () => {
    const fixture = TestBed.createComponent(HousingRiskComponent);
    fixture.detectChanges();
    expect(fixture.nativeElement).toBeTruthy();
  });

  it('C-02: shows four result cards after 200 OK', async () => {
    const fixture = TestBed.createComponent(HousingRiskComponent);
    fixture.detectChanges();

    fixture.componentInstance.evaluate();
    const req = httpMock.expectOne(API_URL);
    req.flush(mockResponse);
    fixture.detectChanges();

    const cards = fixture.nativeElement.querySelectorAll('.result-card');
    expect(cards.length).toBe(4);
  });

  it('C-03: shows validation error message after 400', async () => {
    const fixture = TestBed.createComponent(HousingRiskComponent);
    fixture.detectChanges();

    fixture.componentInstance.evaluate();
    const req = httpMock.expectOne(API_URL);
    req.flush(
      { error: 'Validation failed', fields: { floor: 'floor must be >= 0' } },
      { status: 400, statusText: 'Bad Request' }
    );
    fixture.detectChanges();

    const error = fixture.nativeElement.querySelector('.error-msg') as HTMLElement;
    expect(error).toBeTruthy();
    expect(error.textContent).toContain('Błąd walidacji');
  });

  it('C-04: shows connection error after status 0', async () => {
    const fixture = TestBed.createComponent(HousingRiskComponent);
    fixture.detectChanges();

    fixture.componentInstance.evaluate();
    const req = httpMock.expectOne(API_URL);
    req.flush(null, { status: 0, statusText: 'Unknown Error' });
    fixture.detectChanges();

    const error = fixture.nativeElement.querySelector('.error-msg') as HTMLElement;
    expect(error).toBeTruthy();
    expect(error.textContent).toContain('Nie można połączyć się z API');
  });
});
