export interface ChatResponse {
  provider: string;
  model: string;
  continuation_id?: string;
  output_text: string;
}
