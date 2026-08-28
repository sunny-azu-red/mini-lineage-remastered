// Wires jest-dom's matchers (toBeInTheDocument, toBeDisabled, etc.) into every client component
// test. Referenced by vitest.config.mts's 'client' project via `test.setupFiles`.
import '@testing-library/jest-dom';
