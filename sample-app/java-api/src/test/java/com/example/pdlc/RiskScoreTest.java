package com.example.pdlc;

import static org.junit.jupiter.api.Assertions.assertEquals;

import org.junit.jupiter.api.Test;

class RiskScoreTest {
    @Test
    void classifiesLowRisk() {
        RiskScore score = RiskScore.fromDimensions(0, 1, 0, 1, 0, 1);

        assertEquals(3, score.total());
        assertEquals("low", score.riskClass());
    }

    @Test
    void classifiesHighRisk() {
        RiskScore score = RiskScore.fromDimensions(2, 2, 2, 2, 1, 1);

        assertEquals(10, score.total());
        assertEquals("high", score.riskClass());
    }

    @Test
    void classifiesCriticalRisk() {
        RiskScore score = RiskScore.fromDimensions(15, 15, 15, 15, 15, 15);

        assertEquals(90, score.total());
        assertEquals("critical", score.riskClass());
    }

    @Test
    void criticalBoundary_justBelow_isRegulated() {
        RiskScore score = RiskScore.fromDimensions(14, 15, 15, 15, 15, 15);

        assertEquals(89, score.total());
        assertEquals("regulated", score.riskClass());
    }
}

