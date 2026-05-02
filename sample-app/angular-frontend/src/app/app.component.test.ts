import { describe, it, expect } from 'vitest';
import { classifyRisk } from './risk-summary';

// AppComponent signal: score = 7 initially; summary.riskClass = classifyRisk(score())
// Input max was changed to 100 to allow critical-tier entry.
describe('AppComponent risk display', () => {
  it('initial score 7 produces medium', () => {
    expect(classifyRisk(7)).toBe('medium');
  });

  it('score at input max (100) produces critical', () => {
    expect(classifyRisk(100)).toBe('critical');
  });

  it('critical boundary 90 produces critical', () => {
    expect(classifyRisk(90)).toBe('critical');
  });

  it('just below critical boundary (89) produces regulated', () => {
    expect(classifyRisk(89)).toBe('regulated');
  });

  it('score 0 produces low', () => {
    expect(classifyRisk(0)).toBe('low');
  });
});
