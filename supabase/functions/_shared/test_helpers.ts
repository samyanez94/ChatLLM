export function assert(
  condition: boolean,
  message = "Assertion failed",
): asserts condition {
  if (!condition) {
    throw new Error(message);
  }
}

export function assertEquals<T>(actual: T, expected: T): void {
  if (JSON.stringify(actual) !== JSON.stringify(expected)) {
    throw new Error(
      `Expected ${JSON.stringify(expected)}, received ${
        JSON.stringify(actual)
      }`,
    );
  }
}

export function assertChatAPIError(
  error: unknown,
  code: string,
  status: number,
): void {
  assert(error instanceof Error, "Expected an Error instance");
  assert("code" in error, "Expected an API error code");
  assert("status" in error, "Expected an API error status");
  assertEquals(error.code, code);
  assertEquals(error.status, status);
}

export async function captureError(
  operation: () => unknown | Promise<unknown>,
): Promise<unknown> {
  try {
    await operation();
  } catch (error) {
    return error;
  }
  throw new Error("Expected operation to throw");
}
