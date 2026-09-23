double blankPenaltyFor(int sensitivity) =>
    const [-1.0, -0.5, 0.0, 0.5, 1.0][sensitivity.clamp(kMinVoiceSensitivity, kMaxVoiceSensitivity) - 1];

const kMinVoiceSensitivity = 1;
const kMaxVoiceSensitivity = 5;
const kDefaultVoiceSensitivity = 3;
