import { describe, it, expect } from 'vitest';
import { classifyRisk } from './risk-summary';

describe('classifyRisk', () => {
  it('returns critical for score >= 90', () => {
    expect(classifyRisk(90)).toBe('critical');
    expect(classifyRisk(100)).toBe('critical');
  });

  it('returns regulated for score >= 14 and < 90', () => {
    expect(classifyRisk(14)).toBe('regulated');
    expect(classifyRisk(89)).toBe('regulated');
  });

  it('returns high for score >= 10 and < 14', () => {
    expect(classifyRisk(10)).toBe('high');
    expect(classifyRisk(13)).toBe('high');
  });

  it('returns medium for score >= 6 and < 10', () => {
    expect(classifyRisk(6)).toBe('medium');
    expect(classifyRisk(9)).toBe('medium');
  });

  it('returns low for score < 6', () => {
    expect(classifyRisk(5)).toBe('low');
    expect(classifyRisk(0)).toBe('low');
  });
});
