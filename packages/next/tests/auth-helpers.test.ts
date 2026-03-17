import { describe, it, expect, beforeEach, vi } from 'vitest';
import { mockCookieStore } from './setup';
import { initSpreeNext, resetClient } from '../src/config';

const mockClient = {
  auth: {
    refresh: vi.fn(),
    logout: vi.fn(),
  },
};

vi.mock('@spree/sdk', () => {
  class SpreeError extends Error {
    public readonly status: number;
    constructor(response: { error: { message: string } }, status: number) {
      super(response.error.message);
      this.status = status;
    }
  }
  return {
    createClient: vi.fn(() => mockClient),
    SpreeError,
  };
});

import { getAuthOptions, withAuthRefresh } from '../src/auth-helpers';
import { SpreeError } from '@spree/sdk';

// Helper: create a JWT with a specific expiration time
function makeJwt(expInSeconds: number): string {
  const payload = { exp: expInSeconds };
  return `header.${btoa(JSON.stringify(payload))}.signature`;
}

// Helper: mock cookies to return different values for different cookie names
function mockCookies(values: Record<string, string | undefined>) {
  mockCookieStore.get.mockImplementation((name: string) => {
    const value = values[name];
    return value ? { value } : undefined;
  });
}

describe('auth-helpers', () => {
  beforeEach(() => {
    vi.clearAllMocks();
    resetClient();
    initSpreeNext({ baseUrl: 'https://api.test.com', publishableKey: 'pk_test' });
  });

  describe('getAuthOptions', () => {
    it('returns empty object when no token', async () => {
      mockCookies({});
      const options = await getAuthOptions();
      expect(options).toEqual({});
    });

    it('returns token without refresh when far from expiry', async () => {
      const futureExp = Math.floor(Date.now() / 1000) + 86400; // 24h from now
      const jwt = makeJwt(futureExp);
      mockCookies({ '_spree_jwt': jwt });

      const options = await getAuthOptions();
      expect(options).toEqual({ token: jwt });
      expect(mockClient.auth.refresh).not.toHaveBeenCalled();
    });

    it('refreshes token using refresh_token when near expiry', async () => {
      const nearExp = Math.floor(Date.now() / 1000) + 120; // 2min from now (< 5min threshold)
      const jwt = makeJwt(nearExp);
      const newJwt = 'refreshed_token';
      mockCookies({ '_spree_jwt': jwt, '_spree_refresh_token': 'rt_old' });
      mockClient.auth.refresh.mockResolvedValue({ token: newJwt, refresh_token: 'rt_new' });

      const options = await getAuthOptions();
      expect(options).toEqual({ token: newJwt });
      expect(mockClient.auth.refresh).toHaveBeenCalledWith({ refresh_token: 'rt_old' });
      expect(mockCookieStore.set).toHaveBeenCalledWith(
        '_spree_jwt',
        newJwt,
        expect.any(Object)
      );
      expect(mockCookieStore.set).toHaveBeenCalledWith(
        '_spree_refresh_token',
        'rt_new',
        expect.any(Object)
      );
    });

    it('uses original token when no refresh token available near expiry', async () => {
      const nearExp = Math.floor(Date.now() / 1000) + 120;
      const jwt = makeJwt(nearExp);
      mockCookies({ '_spree_jwt': jwt }); // no refresh token cookie

      const options = await getAuthOptions();
      expect(options).toEqual({ token: jwt });
    });

    it('uses original token when refresh fails near expiry', async () => {
      const nearExp = Math.floor(Date.now() / 1000) + 120;
      const jwt = makeJwt(nearExp);
      mockCookies({ '_spree_jwt': jwt, '_spree_refresh_token': 'rt_old' });
      mockClient.auth.refresh.mockRejectedValue(new Error('Refresh failed'));

      const options = await getAuthOptions();
      expect(options).toEqual({ token: jwt });
    });

    it('uses token as-is when JWT cannot be decoded', async () => {
      const malformedJwt = 'not-a-valid-jwt';
      mockCookies({ '_spree_jwt': malformedJwt });

      const options = await getAuthOptions();
      expect(options).toEqual({ token: malformedJwt });
      expect(mockClient.auth.refresh).not.toHaveBeenCalled();
    });
  });

  describe('withAuthRefresh', () => {
    it('throws when not authenticated', async () => {
      mockCookies({});
      const fn = vi.fn();

      await expect(withAuthRefresh(fn)).rejects.toThrow('Not authenticated');
      expect(fn).not.toHaveBeenCalled();
    });

    it('calls fn with auth options and returns result', async () => {
      const futureExp = Math.floor(Date.now() / 1000) + 86400;
      const jwt = makeJwt(futureExp);
      mockCookies({ '_spree_jwt': jwt });
      const fn = vi.fn().mockResolvedValue({ data: 'result' });

      const result = await withAuthRefresh(fn);
      expect(result).toEqual({ data: 'result' });
      expect(fn).toHaveBeenCalledWith(expect.objectContaining({ token: jwt }));
    });

    it('retries with refreshed token on 401', async () => {
      const futureExp = Math.floor(Date.now() / 1000) + 86400;
      const jwt = makeJwt(futureExp);
      const newJwt = 'refreshed_token';
      mockCookies({ '_spree_jwt': jwt, '_spree_refresh_token': 'rt_old' });

      const error401 = new SpreeError({ error: { message: 'Unauthorized' } } as any, 401);
      const fn = vi.fn()
        .mockRejectedValueOnce(error401)
        .mockResolvedValueOnce({ data: 'retried' });
      mockClient.auth.refresh.mockResolvedValue({ token: newJwt, refresh_token: 'rt_new' });

      const result = await withAuthRefresh(fn);
      expect(result).toEqual({ data: 'retried' });
      expect(fn).toHaveBeenCalledTimes(2);
      expect(fn).toHaveBeenLastCalledWith({ token: newJwt });
      expect(mockClient.auth.refresh).toHaveBeenCalledWith({ refresh_token: 'rt_old' });
    });

    it('clears tokens and rethrows when refresh fails on 401', async () => {
      const futureExp = Math.floor(Date.now() / 1000) + 86400;
      const jwt = makeJwt(futureExp);
      mockCookies({ '_spree_jwt': jwt, '_spree_refresh_token': 'rt_old' });

      const error401 = new SpreeError({ error: { message: 'Unauthorized' } } as any, 401);
      const fn = vi.fn().mockRejectedValue(error401);
      mockClient.auth.refresh.mockRejectedValue(new Error('Refresh failed'));

      await expect(withAuthRefresh(fn)).rejects.toThrow('Unauthorized');
      // Both tokens should be cleared
      expect(mockCookieStore.set).toHaveBeenCalledWith(
        '_spree_jwt',
        '',
        expect.objectContaining({ maxAge: -1 })
      );
      expect(mockCookieStore.set).toHaveBeenCalledWith(
        '_spree_refresh_token',
        '',
        expect.objectContaining({ maxAge: -1 })
      );
    });

    it('rethrows non-401 errors without refresh', async () => {
      const futureExp = Math.floor(Date.now() / 1000) + 86400;
      const jwt = makeJwt(futureExp);
      mockCookies({ '_spree_jwt': jwt });

      const error500 = new Error('Server error');
      const fn = vi.fn().mockRejectedValue(error500);

      await expect(withAuthRefresh(fn)).rejects.toThrow('Server error');
      expect(mockClient.auth.refresh).not.toHaveBeenCalled();
    });
  });
});
