import dayjs from "dayjs";

export default function useDateTimeParser() {
  const toUnixTime = (value: string): number => {
    console.log(value)
    if (!value) return 0;
    return dayjs(value, "YYYY-MM-DD HH:mm").unix();
  };

  const toText = (value: number): string => {
    if (!value) return "";
    return dayjs.unix(value).format("YYYY-MM-DD HH:mm");
  };

  return {
    toUnixTime,
    toText,
  };
}
