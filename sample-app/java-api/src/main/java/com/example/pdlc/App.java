package com.example.pdlc;

public final class App {
    private App() {
    }

    public static void main(String[] args) {
        RiskScore score = RiskScore.fromDimensions(1, 1, 1, 2, 1, 1);
        System.out.printf("sample-risk-java-api riskClass=%s total=%d%n", score.riskClass(), score.total());
    }
}

