import { AsyncLocalStorage } from 'async_hooks';
import { RequestContext } from '@/interface';

export const requestContext = new AsyncLocalStorage<RequestContext>();
