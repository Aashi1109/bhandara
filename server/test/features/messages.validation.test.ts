import { describe, expect, it } from 'vitest';

import { validateMessageCreate } from '@/features/messages/validation';

const basePayload = {
  userId: '019d196e-530f-76ba-a118-ec3806519832',
  threadId: '019d42e5-e35d-7394-8b64-e6b9e394d01d',
  isEdited: false,
};

describe('message validation', () => {
  it('accepts plain text object content', () => {
    const payload = {
      ...basePayload,
      content: { text: 'aksdlasd' },
    };

    const result = validateMessageCreate(payload, (validData) => validData);

    expect(result).toEqual(payload);
  });

  it('accepts plain string content', () => {
    const payload = {
      ...basePayload,
      content: 'aksdlasd',
    };

    const result = validateMessageCreate(payload, (validData) => validData);

    expect(result).toEqual(payload);
  });

  it('accepts rich media content with media required', () => {
    const payload = {
      ...basePayload,
      content: {
        text: 'photo',
        media: ['019d196e-530f-76ba-a118-ec3806519833'],
      },
    };

    const result = validateMessageCreate(payload, (validData) => validData);

    expect(result).toEqual(payload);
  });
});
