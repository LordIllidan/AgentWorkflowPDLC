import { describe, it, expect, beforeEach } from 'vitest';
import { TestBed } from '@angular/core/testing';
import { AppComponent } from './app.component';

describe('AppComponent display', () => {
  beforeEach(async () => {
    await TestBed.configureTestingModule({
      imports: [AppComponent],
    }).compileComponents();
  });

  it('renders medium for initial score 7', () => {
    const fixture = TestBed.createComponent(AppComponent);
    fixture.detectChanges();
    const strong = fixture.nativeElement.querySelector('strong') as HTMLElement;
    expect(strong.textContent?.trim().toLowerCase()).toBe('medium');
  });

  it('renders critical after input changes to 90', () => {
    const fixture = TestBed.createComponent(AppComponent);
    fixture.detectChanges();
    const input = fixture.nativeElement.querySelector('input') as HTMLInputElement;
    input.value = '90';
    input.dispatchEvent(new Event('input'));
    fixture.detectChanges();
    const strong = fixture.nativeElement.querySelector('strong') as HTMLElement;
    expect(strong.textContent?.trim().toLowerCase()).toBe('critical');
  });

  it('renders low after input changes to 0', () => {
    const fixture = TestBed.createComponent(AppComponent);
    fixture.detectChanges();
    const input = fixture.nativeElement.querySelector('input') as HTMLInputElement;
    input.value = '0';
    input.dispatchEvent(new Event('input'));
    fixture.detectChanges();
    const strong = fixture.nativeElement.querySelector('strong') as HTMLElement;
    expect(strong.textContent?.trim().toLowerCase()).toBe('low');
  });
});
