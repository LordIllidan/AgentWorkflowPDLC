package com.example.pdlc;

public record RiskScore(int total, String riskClass) {
    public static RiskScore fromDimensions(
            int userImpact,
            int technicalComplexity,
            int data,
            int security,
            int reversibility,
            int requirementsUncertainty) {
        int total = userImpact
                + technicalComplexity
                + data
                + security
                + reversibility
                + requirementsUncertainty;

        return new RiskScore(total, classify(total));
    }

    private static String classify(int total) {
        if (total >= 14) {
            return "regulated";
        }
        if (total >= 10) {
            return "high";
        }
        if (total >= 6) {
            return "medium";
        }
        return "low";
    }
}

